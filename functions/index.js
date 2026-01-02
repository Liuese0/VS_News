// functions/index.js
// Firebase Cloud Functions - Device-Registered UID 발급 시스템

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();
const db = admin.firestore();

// 서버 시크릿 키 (실제 배포 시 Firebase Config에서 관리)
const SECRET_KEY = functions.config().app?.secret || 'your-super-secret-key-change-in-production';

/**
 * 기기 ID로부터 해시 생성
 */
function generateDeviceHash(deviceId) {
  return crypto
    .createHmac('sha256', SECRET_KEY)
    .update(deviceId)
    .digest('hex');
}

/**
 * 랜덤 UID 생성
 */
function generateRandomUID() {
  return crypto.randomBytes(16).toString('hex');
}

/**
 * 기기 등록 및 UID 발급
 * 클라이언트가 deviceId를 보내면 서버에서 검증 후 UID 발급
 */
exports.registerDevice = functions.https.onCall(async (data, context) => {
  const { deviceId, platform, appVersion } = data;

  if (!deviceId || deviceId.length < 10) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Invalid device ID'
    );
  }

  const deviceHash = generateDeviceHash(deviceId);

  try {
    // 이미 등록된 기기인지 확인
    const existingQuery = await db
      .collection('users')
      .where('deviceHash', '==', deviceHash)
      .limit(1)
      .get();

    if (!existingQuery.empty) {
      // 이미 등록된 기기 - 기존 UID 반환
      const existingDoc = existingQuery.docs[0];
      const userData = existingDoc.data();
      
      // 마지막 로그인 시간 업데이트
      await existingDoc.ref.update({
        lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
        lastPlatform: platform,
        lastAppVersion: appVersion,
      });

      return {
        success: true,
        uid: existingDoc.id,
        isNewUser: false,
        nickname: userData.nickname,
        tokenCount: userData.tokenCount || 0,
      };
    }

    // 새 기기 등록
    const uid = generateRandomUID();
    const nickname = `익명${Date.now() % 100000}`;

    await db.collection('users').doc(uid).set({
      deviceHash: deviceHash,
      nickname: nickname,
      tokenCount: 100, // 초기 토큰 지급
      favoriteCount: 0,
      commentCount: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
      platform: platform,
      appVersion: appVersion,
      status: 'active',
    });

    // 초기 토큰 지급 기록
    await db.collection('users').doc(uid).collection('tokenHistory').add({
      type: 'welcome_bonus',
      amount: 100,
      balance: 100,
      description: '가입 축하 토큰',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      uid: uid,
      isNewUser: true,
      nickname: nickname,
      tokenCount: 100,
    };

  } catch (error) {
    console.error('Device registration error:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to register device'
    );
  }
});

/**
 * UID 검증
 * 클라이언트가 저장된 UID가 유효한지 확인
 */
exports.verifyUID = functions.https.onCall(async (data, context) => {
  const { uid, deviceId } = data;

  if (!uid || !deviceId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'UID and deviceId are required'
    );
  }

  const deviceHash = generateDeviceHash(deviceId);

  try {
    const userDoc = await db.collection('users').doc(uid).get();

    if (!userDoc.exists) {
      return { valid: false, reason: 'user_not_found' };
    }

    const userData = userDoc.data();

    // deviceHash 일치 확인
    if (userData.deviceHash !== deviceHash) {
      return { valid: false, reason: 'device_mismatch' };
    }

    // 계정 상태 확인
    if (userData.status !== 'active') {
      return { valid: false, reason: 'account_inactive' };
    }

    // 마지막 로그인 시간 업데이트
    await userDoc.ref.update({
      lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      valid: true,
      nickname: userData.nickname,
      tokenCount: userData.tokenCount || 0,
      favoriteCount: userData.favoriteCount || 0,
      commentCount: userData.commentCount || 0,
    };

  } catch (error) {
    console.error('UID verification error:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to verify UID'
    );
  }
});

/**
 * 인기 토론 캐시 갱신 (10분마다 실행)
 */
exports.updatePopularDiscussions = functions.pubsub
  .schedule('every 10 minutes')
  .onRun(async (context) => {
    try {
      // 참여자 수 기준 상위 20개 토론 조회
      const discussionsQuery = await db
        .collection('discussions')
        .orderBy('participantCount', 'desc')
        .limit(20)
        .get();

      const popularItems = discussionsQuery.docs.map(doc => ({
        id: doc.id,
        title: doc.data().title,
        newsUrl: doc.data().newsUrl,
        participantCount: doc.data().participantCount || 0,
        commentCount: doc.data().commentCount || 0,
        category: doc.data().category,
        imageUrl: doc.data().imageUrl,
        source: doc.data().source,
        lastActivityAt: doc.data().lastActivityAt,
      }));

      // 캐시 문서 업데이트
      await db.collection('cache').doc('popularDiscussions').set({
        items: popularItems,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`Updated popular discussions cache: ${popularItems.length} items`);
      return null;

    } catch (error) {
      console.error('Failed to update popular discussions:', error);
      return null;
    }
  });

/**
 * 댓글 작성 시 연관 데이터 업데이트 (트랜잭션)
 */
exports.onCommentCreated = functions.firestore
  .document('comments/{commentId}')
  .onCreate(async (snap, context) => {
    const comment = snap.data();
    const { discussionId, uid, newsUrl } = comment;

    try {
      await db.runTransaction(async (transaction) => {
        // 1. 유저 문서 업데이트
        const userRef = db.collection('users').doc(uid);
        const userDoc = await transaction.get(userRef);
        
        if (userDoc.exists) {
          transaction.update(userRef, {
            commentCount: admin.firestore.FieldValue.increment(1),
          });
        }

        // 2. 유저의 참여 토론 기록 추가/업데이트
        const participatedRef = db
          .collection('users')
          .doc(uid)
          .collection('participatedDiscussions')
          .doc(discussionId);
        
        transaction.set(participatedRef, {
          discussionId: discussionId,
          newsUrl: newsUrl,
          lastCommentAt: admin.firestore.FieldValue.serverTimestamp(),
          commentCount: admin.firestore.FieldValue.increment(1),
        }, { merge: true });

        // 3. 토론 문서 업데이트
        const discussionRef = db.collection('discussions').doc(discussionId);
        const discussionDoc = await transaction.get(discussionRef);
        
        if (discussionDoc.exists) {
          transaction.update(discussionRef, {
            commentCount: admin.firestore.FieldValue.increment(1),
            lastActivityAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // 참여자 수 업데이트 (고유 사용자 수)
          const participants = discussionDoc.data().participants || [];
          if (!participants.includes(uid)) {
            transaction.update(discussionRef, {
              participants: admin.firestore.FieldValue.arrayUnion(uid),
              participantCount: admin.firestore.FieldValue.increment(1),
            });
          }
        }
      });

      console.log(`Comment created: ${context.params.commentId}`);
      return null;

    } catch (error) {
      console.error('Failed to process comment creation:', error);
      return null;
    }
  });

/**
 * 즐겨찾기 토글
 */
exports.toggleFavorite = functions.https.onCall(async (data, context) => {
  const { uid, newsId, newsData } = data;

  if (!uid || !newsId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'UID and newsId are required'
    );
  }

  const favoriteId = `${uid}_${newsId}`;
  const favoriteRef = db.collection('favorites').doc(favoriteId);

  try {
    const favoriteDoc = await favoriteRef.get();

    if (favoriteDoc.exists) {
      // 즐겨찾기 해제
      await db.runTransaction(async (transaction) => {
        transaction.delete(favoriteRef);
        transaction.update(db.collection('users').doc(uid), {
          favoriteCount: admin.firestore.FieldValue.increment(-1),
        });
      });

      return { success: true, action: 'removed' };
    } else {
      // 즐겨찾기 추가
      await db.runTransaction(async (transaction) => {
        transaction.set(favoriteRef, {
          uid: uid,
          newsId: newsId,
          newsData: newsData,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        transaction.update(db.collection('users').doc(uid), {
          favoriteCount: admin.firestore.FieldValue.increment(1),
        });
      });

      return { success: true, action: 'added' };
    }

  } catch (error) {
    console.error('Toggle favorite error:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to toggle favorite'
    );
  }
});

/**
 * 토큰 사용/지급
 */
exports.updateTokens = functions.https.onCall(async (data, context) => {
  const { uid, amount, type, description } = data;

  if (!uid || amount === undefined || !type) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'UID, amount, and type are required'
    );
  }

  const userRef = db.collection('users').doc(uid);

  try {
    const result = await db.runTransaction(async (transaction) => {
      const userDoc = await transaction.get(userRef);

      if (!userDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'User not found');
      }

      const currentTokens = userDoc.data().tokenCount || 0;
      const newBalance = currentTokens + amount;

      if (newBalance < 0) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Insufficient tokens'
        );
      }

      // 토큰 업데이트
      transaction.update(userRef, {
        tokenCount: newBalance,
      });

      // 토큰 히스토리 기록
      const historyRef = userRef.collection('tokenHistory').doc();
      transaction.set(historyRef, {
        type: type,
        amount: amount,
        balance: newBalance,
        description: description || '',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { newBalance };
    });

    return {
      success: true,
      tokenCount: result.newBalance,
    };

  } catch (error) {
    console.error('Update tokens error:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError(
      'internal',
      'Failed to update tokens'
    );
  }
});

/**
 * 닉네임 변경
 */
exports.updateNickname = functions.https.onCall(async (data, context) => {
  const { uid, nickname } = data;

  if (!uid || !nickname) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'UID and nickname are required'
    );
  }

  // 닉네임 유효성 검사
  if (nickname.length < 2 || nickname.length > 20) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Nickname must be 2-20 characters'
    );
  }

  try {
    await db.collection('users').doc(uid).update({
      nickname: nickname,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, nickname: nickname };

  } catch (error) {
    console.error('Update nickname error:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to update nickname'
    );
  }
});

/**
 * 일일 출석체크 보상 지급
 * 평일: 10 토큰, 주말(토/일): 30 토큰
 */
exports.claimDailyReward = functions.https.onCall(async (data, context) => {
  const { uid } = data;

  if (!uid) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'UID is required'
    );
  }

  try {
    // 한국 시간대로 오늘 날짜 계산 (UTC+9)
    const now = new Date();
    const koreaOffset = 9 * 60; // 9시간을 분으로
    const koreaTime = new Date(now.getTime() + koreaOffset * 60 * 1000);
    const todayDate = koreaTime.toISOString().split('T')[0]; // YYYY-MM-DD
    const dayOfWeek = koreaTime.getDay(); // 0=일요일, 6=토요일

    // 주말 여부 확인
    const isWeekend = dayOfWeek === 0 || dayOfWeek === 6;
    const rewardTokens = isWeekend ? 30 : 10;

    const userRef = db.collection('users').doc(uid);
    const attendanceRef = userRef.collection('dailyAttendance').doc(todayDate);
    const summaryRef = userRef.collection('attendanceSummary').doc('summary');

    const result = await db.runTransaction(async (transaction) => {
      // 사용자 확인
      const userDoc = await transaction.get(userRef);
      if (!userDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'User not found');
      }

      // 이미 오늘 출석했는지 확인
      const attendanceDoc = await transaction.get(attendanceRef);
      if (attendanceDoc.exists) {
        throw new functions.https.HttpsError(
          'already-exists',
          'Already claimed today\'s reward'
        );
      }

      // 출석 요약 정보 조회
      const summaryDoc = await transaction.get(summaryRef);
      const summaryData = summaryDoc.exists ? summaryDoc.data() : {
        currentStreak: 0,
        maxStreak: 0,
        totalDays: 0,
        lastAttendanceDate: null,
      };

      // 연속 출석일 계산
      let newStreak = 1;
      if (summaryData.lastAttendanceDate) {
        const lastDate = new Date(summaryData.lastAttendanceDate);
        const todayDateObj = new Date(todayDate);
        const diffTime = todayDateObj - lastDate;
        const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));

        if (diffDays === 1) {
          // 연속 출석
          newStreak = summaryData.currentStreak + 1;
        } else if (diffDays === 0) {
          // 같은 날 (이미 위에서 체크했지만 안전장치)
          throw new functions.https.HttpsError(
            'already-exists',
            'Already claimed today\'s reward'
          );
        }
        // diffDays > 1이면 연속 끊김, newStreak = 1 유지
      }

      const newMaxStreak = Math.max(newStreak, summaryData.maxStreak);

      // 토큰 업데이트
      const currentTokens = userDoc.data().tokenCount || 0;
      const newBalance = currentTokens + rewardTokens;

      transaction.update(userRef, {
        tokenCount: newBalance,
      });

      // 토큰 히스토리 기록
      const historyRef = userRef.collection('tokenHistory').doc();
      transaction.set(historyRef, {
        type: 'daily_attendance',
        amount: rewardTokens,
        balance: newBalance,
        description: isWeekend ? '주말 출석 보상' : '일일 출석 보상',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 출석 기록 생성
      transaction.set(attendanceRef, {
        date: todayDate,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        rewardTokens: rewardTokens,
        dayOfWeek: dayOfWeek,
        consecutiveDays: newStreak,
        isWeekend: isWeekend,
      });

      // 출석 요약 업데이트
      transaction.set(summaryRef, {
        currentStreak: newStreak,
        maxStreak: newMaxStreak,
        totalDays: summaryData.totalDays + 1,
        lastAttendanceDate: todayDate,
        lastClaimedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        rewardTokens,
        newBalance,
        consecutiveDays: newStreak,
        totalDays: summaryData.totalDays + 1,
        isWeekend,
      };
    });

    console.log(`Daily reward claimed: uid=${uid}, date=${todayDate}, reward=${rewardTokens}`);

    return {
      success: true,
      ...result,
    };

  } catch (error) {
    console.error('Claim daily reward error:', error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError(
      'internal',
      'Failed to claim daily reward'
    );
  }
});

/**
 * 출석 현황 조회
 */
exports.getAttendanceStatus = functions.https.onCall(async (data, context) => {
  const { uid } = data;

  if (!uid) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'UID is required'
    );
  }

  try {
    // 한국 시간대로 오늘 날짜 계산
    const now = new Date();
    const koreaOffset = 9 * 60;
    const koreaTime = new Date(now.getTime() + koreaOffset * 60 * 1000);
    const todayDate = koreaTime.toISOString().split('T')[0];

    const userRef = db.collection('users').doc(uid);
    const attendanceRef = userRef.collection('dailyAttendance').doc(todayDate);
    const summaryRef = userRef.collection('attendanceSummary').doc('summary');

    const [attendanceDoc, summaryDoc] = await Promise.all([
      attendanceRef.get(),
      summaryRef.get(),
    ]);

    const hasClaimedToday = attendanceDoc.exists;
    const summaryData = summaryDoc.exists ? summaryDoc.data() : {
      currentStreak: 0,
      maxStreak: 0,
      totalDays: 0,
      lastAttendanceDate: null,
    };

    return {
      success: true,
      hasClaimedToday,
      todayDate,
      currentStreak: summaryData.currentStreak,
      maxStreak: summaryData.maxStreak,
      totalDays: summaryData.totalDays,
      lastAttendanceDate: summaryData.lastAttendanceDate,
    };

  } catch (error) {
    console.error('Get attendance status error:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to get attendance status'
    );
  }
});