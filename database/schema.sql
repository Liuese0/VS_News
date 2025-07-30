-- 데이터베이스 생성
CREATE DATABASE IF NOT EXISTS news_debater
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE news_debater;

-- 이슈(사건) 테이블
CREATE TABLE issues (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    summary TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    positive_percent FLOAT DEFAULT 50.0,
    negative_percent FLOAT DEFAULT 50.0,
    debate_score FLOAT DEFAULT 0.0,
    INDEX idx_debate_score (debate_score DESC),
    INDEX idx_created_at (created_at DESC)
);

-- 뉴스 테이블
CREATE TABLE news (
    id INT AUTO_INCREMENT PRIMARY KEY,
    issue_id INT NOT NULL,
    stance ENUM('pro', 'con') NOT NULL,
    title VARCHAR(255) NOT NULL,
    summary TEXT NOT NULL,
    url TEXT NOT NULL,
    source VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (issue_id) REFERENCES issues(id) ON DELETE CASCADE,
    INDEX idx_issue_stance (issue_id, stance)
);

-- 투표 테이블
CREATE TABLE votes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    issue_id INT NOT NULL,
    user_id VARCHAR(255) NOT NULL,
    vote ENUM('pro', 'con') NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (issue_id) REFERENCES issues(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_vote (issue_id, user_id),
    INDEX idx_issue_vote (issue_id, vote)
);

-- 댓글 테이블
CREATE TABLE comments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    issue_id INT NOT NULL,
    user_id VARCHAR(255) NOT NULL,
    nickname VARCHAR(50) NOT NULL,
    stance ENUM('pro', 'con') NOT NULL,
    content TEXT NOT NULL,
    likes INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (issue_id) REFERENCES issues(id) ON DELETE CASCADE,
    INDEX idx_issue_created (issue_id, created_at DESC),
    INDEX idx_issue_likes (issue_id, likes DESC)
);

-- 샘플 데이터 삽입
INSERT INTO issues (title, summary, positive_percent, negative_percent, debate_score) VALUES
('최저임금 인상 정책', '정부가 발표한 내년도 최저임금 9% 인상안에 대한 찬반 논쟁이 뜨겁습니다. 노동계는 환영하지만 소상공인들은 부담을 호소하고 있습니다.', 45.2, 54.8, 90.4),
('주 4일제 도입', '일부 기업들이 시범적으로 도입한 주 4일제에 대한 사회적 논의가 활발합니다. 워라밸과 생산성 사이에서 의견이 갈리고 있습니다.', 62.3, 37.7, 75.4),
('원전 추가 건설', '탄소중립 달성을 위한 원전 추가 건설 계획에 대해 환경단체와 산업계의 입장이 대립하고 있습니다.', 51.1, 48.9, 97.8);

-- 뉴스 샘플 데이터
INSERT INTO news (issue_id, stance, title, summary, url, source) VALUES
(1, 'pro', '최저임금 인상, 내수 활성화 기대', '전문가들은 최저임금 인상이 소비 증가로 이어져 경제 선순환을 만들 것이라고 전망했다.', 'https://example.com/news1', '경제일보'),
(1, 'con', '소상공인 "인건비 부담 한계"', '자영업자 단체는 최저임금 급격한 인상이 고용 감소로 이어질 것이라고 우려를 표명했다.', 'https://example.com/news2', '중앙일보'),
(2, 'pro', '주 4일제 도입 기업 "생산성 오히려 향상"', 'IT 기업 A사는 주 4일제 도입 후 직원 만족도와 생산성이 모두 상승했다고 발표했다.', 'https://example.com/news3', '테크뉴스'),
(2, 'con', '제조업계 "현실적으로 불가능"', '제조업 협회는 24시간 가동이 필요한 산업 특성상 주 4일제는 비현실적이라고 주장했다.', 'https://example.com/news4', '산업일보');

-- 저장 프로시저: 논쟁 지수 자동 계산
DELIMITER //
CREATE PROCEDURE update_debate_score(IN issue_id INT)
BEGIN
    DECLARE pro_count INT;
    DECLARE con_count INT;
    DECLARE total_votes INT;
    DECLARE pos_percent FLOAT;
    DECLARE neg_percent FLOAT;
    DECLARE debate_score FLOAT;

    -- 투표 수 계산
    SELECT
        SUM(CASE WHEN vote = 'pro' THEN 1 ELSE 0 END),
        SUM(CASE WHEN vote = 'con' THEN 1 ELSE 0 END),
        COUNT(*)
    INTO pro_count, con_count, total_votes
    FROM votes
    WHERE votes.issue_id = issue_id;

    -- 비율 계산
    IF total_votes > 0 THEN
        SET pos_percent = (pro_count / total_votes) * 100;
        SET neg_percent = (con_count / total_votes) * 100;
    ELSE
        SET pos_percent = 50.0;
        SET neg_percent = 50.0;
    END IF;

    -- 논쟁 지수 계산 (찬반이 50:50에 가까울수록 높음)
    SET debate_score = 100 - ABS(pos_percent - neg_percent);

    -- 업데이트
    UPDATE issues
    SET positive_percent = pos_percent,
        negative_percent = neg_percent,
        debate_score = debate_score
    WHERE id = issue_id;
END//
DELIMITER ;