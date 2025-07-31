-- 업데이트된 데이터베이스 스키마
-- database/updated_schema.sql

-- 데이터베이스 생성
CREATE DATABASE IF NOT EXISTS news_debater_v2
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE news_debater_v2;

-- 기존 이슈(사건) 테이블 (확장)
CREATE TABLE issues (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(300) NOT NULL,
    summary TEXT NOT NULL,
    category VARCHAR(50) DEFAULT '기타',
    tags JSON DEFAULT NULL,
    source_type ENUM('manual', 'auto_generated') DEFAULT 'manual',
    auto_confidence_score FLOAT DEFAULT 0.0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    positive_percent FLOAT DEFAULT 50.0,
    negative_percent FLOAT DEFAULT 50.0,
    debate_score FLOAT DEFAULT 0.0,
    total_votes INT DEFAULT 0,
    status ENUM('active', 'inactive', 'archived') DEFAULT 'active',
    INDEX idx_debate_score (debate_score DESC),
    INDEX idx_created_at (created_at DESC),
    INDEX idx_category (category),
    INDEX idx_status (status)
);

-- 자동 수집된 뉴스 테이블
CREATE TABLE auto_collected_news (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(500) NOT NULL,
    description TEXT,
    content LONGTEXT,
    url TEXT NOT NULL,
    image_url TEXT,
    source VARCHAR(100),
    author VARCHAR(200),
    published_at TIMESTAMP NULL,
    collected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    auto_category VARCHAR(50) DEFAULT '기타',
    auto_tags JSON DEFAULT NULL,
    auto_confidence_score FLOAT DEFAULT 0.0,
    sentiment_score FLOAT DEFAULT 0.0, -- 감정 점수 (-1: 부정, 0: 중립, 1: 긍정)
    controversy_score FLOAT DEFAULT 0.0, -- 논쟁성 점수 (0-100)
    is_processed BOOLEAN DEFAULT FALSE,
    language VARCHAR(10) DEFAULT 'ko',
    INDEX idx_auto_category (auto_category),
    INDEX idx_published_at (published_at DESC),
    INDEX idx_collected_at (collected_at DESC),
    INDEX idx_controversy_score (controversy_score DESC),
    INDEX idx_is_processed (is_processed),
    FULLTEXT(title, description) WITH PARSER ngram
);

-- 뉴스-이슈 연결 테이블 (다대다 관계)
CREATE TABLE issue_news_relations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    issue_id INT NOT NULL,
    news_id INT,
    auto_news_id INT,
    stance ENUM('pro', 'con', 'neutral') DEFAULT 'neutral',
    relevance_score FLOAT DEFAULT 0.0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (issue_id) REFERENCES issues(id) ON DELETE CASCADE,
    FOREIGN KEY (news_id) REFERENCES news(id) ON DELETE CASCADE,
    FOREIGN KEY (auto_news_id) REFERENCES auto_collected_news(id) ON DELETE CASCADE,
    INDEX idx_issue_vote (issue_id, vote)
);

CREATE TABLE comments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    issue_id INT NOT NULL,
    user_id VARCHAR(255) NOT NULL,
    nickname VARCHAR(50) NOT NULL,
    stance ENUM('pro', 'con') NOT NULL,
    content TEXT NOT NULL,
    likes INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (issue_id) REFERENCES issues(id) ON DELETE CASCADE,
    INDEX idx_issue_created (issue_id, created_at DESC),
    INDEX idx_issue_likes (issue_id, likes DESC)
);

-- 초기 카테고리 데이터 삽입
INSERT INTO categories (name, icon, description, sort_order) VALUES
('인기', '🔥', '가장 많이 관심받는 이슈들', 1),
('정치', '🏛️', '정치, 정책, 선거 관련 이슈', 2),
('경제', '💰', '경제, 금융, 투자 관련 이슈', 3),
('산업', '🏭', '산업, 기업, 제조업 관련 이슈', 4),
('사회', '👥', '사회, 교육, 복지 관련 이슈', 5),
('문화', '🎭', '문화, 예술, 관광 관련 이슈', 6),
('과학', '🔬', '과학, 기술, IT 관련 이슈', 7),
('스포츠', '⚽', '스포츠, 경기, 선수 관련 이슈', 8),
('연예', '🎬', '연예, 엔터테인먼트 관련 이슈', 9);

-- 정치 카테고리 태그
INSERT INTO tags (category_id, name, keyword_list, sort_order) VALUES
(2, '국내', '["국내정치", "한국정치", "내정", "국정", "청와대", "국무총리"]', 1),
(2, '글로벌', '["국제정치", "외교", "국제관계", "해외", "외무부", "대사관"]', 2),
(2, '미국', '["미국", "바이든", "트럼프", "백악관", "워싱턴", "국무부"]', 3),
(2, '북한', '["북한", "김정은", "평양", "핵", "미사일", "통일부"]', 4),
(2, '일본', '["일본", "기시다", "도쿄", "독도", "위안부", "과거사"]', 5),
(2, '중국', '["중국", "시진핑", "베이징", "사드", "무역전쟁", "외교부"]', 6);

-- 경제 카테고리 태그
INSERT INTO tags (category_id, name, keyword_list, sort_order) VALUES
(3, '주식', '["주식", "증권", "투자", "상장", "배당", "주주", "코스피", "코스닥"]', 1),
(3, '코인', '["비트코인", "암호화폐", "가상화폐", "블록체인", "이더리움", "코인"]', 2),
(3, '부동산', '["부동산", "아파트", "집값", "전세", "매매", "임대", "분양"]', 3),
(3, '금융', '["은행", "금융", "대출", "예금", "보험", "카드", "핀테크"]', 4),
(3, '무역', '["수출", "수입", "무역", "관세", "무역수지", "FTA", "통상"]', 5);

-- 산업 카테고리 태그
INSERT INTO tags (category_id, name, keyword_list, sort_order) VALUES
(4, '반도체', '["반도체", "칩", "메모리", "삼성전자", "SK하이닉스", "파운드리"]', 1),
(4, '자동차', '["자동차", "현대차", "기아", "전기차", "EV", "배터리"]', 2),
(4, '조선', '["조선", "선박", "현대중공업", "대우조선해양", "삼성중공업"]', 3),
(4, '철강', '["철강", "포스코", "제철", "스테인리스", "철광석"]', 4),
(4, '화학', '["화학", "석유화학", "LG화학", "SK케미칼", "정유"]', 5);

-- 사회 카테고리 태그
INSERT INTO tags (category_id, name, keyword_list, sort_order) VALUES
(5, '교육', '["교육", "학교", "대학", "입시", "수능", "사교육", "교사"]', 1),
(5, '의료', '["의료", "병원", "코로나", "백신", "질병", "의사", "간호사"]', 2),
(5, '환경', '["환경", "기후변화", "탄소중립", "미세먼지", "재활용"]', 3),
(5, '안전', '["안전", "사고", "재해", "화재", "교통사고", "안전사고"]', 4);

-- 문화 카테고리 태그
INSERT INTO tags (category_id, name, keyword_list, sort_order) VALUES
(6, 'K-컬처', '["한류", "K-POP", "K-드라마", "한국문화", "케이컬처"]', 1),
(6, '영화', '["영화", "시네마", "영화제", "박스오피스", "감독", "배우"]', 2),
(6, '드라마', '["드라마", "TV", "방송", "OTT", "넷플릭스", "시청률"]', 3),
(6, '관광', '["관광", "여행", "축제", "문화재", "유네스코", "명소"]', 4);

-- 과학 카테고리 태그
INSERT INTO tags (category_id, name, keyword_list, sort_order) VALUES
(7, 'IT', '["IT", "정보기술", "소프트웨어", "앱", "플랫폼", "디지털"]', 1),
(7, 'AI', '["AI", "인공지능", "머신러닝", "딥러닝", "로봇", "자동화"]', 2),
(7, '바이오', '["바이오", "생명과학", "의학", "신약", "백신", "유전자"]', 3),
(7, '우주', '["우주", "항공", "위성", "로켓", "NASA", "달탐사"]', 4);

-- 스포츠 카테고리 태그
INSERT INTO tags (category_id, name, keyword_list, sort_order) VALUES
(8, '축구', '["축구", "월드컵", "손흥민", "국가대표", "K리그", "FIFA"]', 1),
(8, '야구', '["야구", "KBO", "프로야구", "월드베이스볼클래식", "WBC"]', 2),
(8, '올림픽', '["올림픽", "패럴림픽", "아시안게임", "IOC", "금메달"]', 3),
(8, 'e스포츠', '["e스포츠", "게임", "LoL", "프로게이머", "리그오브레전드"]', 4);

-- 연예 카테고리 태그
INSERT INTO tags (category_id, name, keyword_list, sort_order) VALUES
(9, 'K-POP', '["K-POP", "아이돌", "BTS", "블랙핑크", "케이팝", "한류"]', 1),
(9, '드라마', '["드라마", "K-드라마", "넷플릭스", "방송", "배우"]', 2),
(9, '예능', '["예능", "버라이어티", "토크쇼", "MBC", "KBS", "SBS"]', 3),
(9, '영화', '["영화배우", "한국영화", "칸영화제", "아카데미", "시상식"]', 4);

-- 샘플 이슈 데이터 (기존 + 새로운)
INSERT INTO issues (title, summary, category, tags, positive_percent, negative_percent, debate_score, total_votes) VALUES
('최저임금 인상 정책', '정부가 발표한 내년도 최저임금 9% 인상안에 대한 찬반 논쟁이 뜨겁습니다. 노동계는 환영하지만 소상공인들은 부담을 호소하고 있습니다.', '경제', '["정책", "임금", "소상공인"]', 45.2, 54.8, 90.4, 1247),
('주 4일제 도입', '일부 기업들이 시범적으로 도입한 주 4일제에 대한 사회적 논의가 활발합니다. 워라밸과 생산성 사이에서 의견이 갈리고 있습니다.', '사회', '["근로시간", "워라밸", "생산성"]', 62.3, 37.7, 75.4, 892),
('원전 추가 건설', '탄소중립 달성을 위한 원전 추가 건설 계획에 대해 환경단체와 산업계의 입장이 대립하고 있습니다.', '과학', '["원전", "탄소중립", "에너지"]', 51.1, 48.9, 97.8, 1653),
('전기차 의무화 정책', '2030년까지 신규 차량의 50%를 전기차로 하는 정책에 대한 논란이 지속되고 있습니다.', '산업', '["전기차", "환경", "자동차산업"]', 58.7, 41.3, 82.6, 756),
('K-POP 병역특례 확대', 'BTS에 이어 다른 K-POP 아티스트들에게도 병역특례를 적용하자는 논의가 활발합니다.', '연예', '["병역", "K-POP", "특례"]', 43.8, 56.2, 87.6, 2103);

-- 샘플 뉴스 데이터
INSERT INTO news (issue_id, stance, title, summary, url, source) VALUES
(1, 'pro', '최저임금 인상, 내수 활성화 기대', '전문가들은 최저임금 인상이 소비 증가로 이어져 경제 선순환을 만들 것이라고 전망했다.', 'https://example.com/news1', '경제일보'),
(1, 'con', '소상공인 "인건비 부담 한계"', '자영업자 단체는 최저임금 급격한 인상이 고용 감소로 이어질 것이라고 우려를 표명했다.', 'https://example.com/news2', '중앙일보'),
(2, 'pro', '주 4일제 도입 기업 "생산성 오히려 향상"', 'IT 기업 A사는 주 4일제 도입 후 직원 만족도와 생산성이 모두 상승했다고 발표했다.', 'https://example.com/news3', '테크뉴스'),
(2, 'con', '제조업계 "현실적으로 불가능"', '제조업 협회는 24시간 가동이 필요한 산업 특성상 주 4일제는 비현실적이라고 주장했다.', 'https://example.com/news4', '산업일보'),
(3, 'pro', '원전, 안전한 청정에너지로 재평가', '최신 원전 기술의 안전성이 대폭 향상되어 탄소중립 달성에 필수적이라는 전문가 의견이 나왔다.', 'https://example.com/news5', '에너지타임즈'),
(3, 'con', '원전 안전성 우려 여전', '후쿠시마 원전사고 12년, 여전히 방사능 오염수 문제가 해결되지 않아 원전 확대에 반대한다는 시민단체 입장이다.', 'https://example.com/news6', '환경일보');

-- 저장 프로시저: 논쟁 지수 자동 계산 (업데이트)
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
        debate_score = debate_score,
        total_votes = total_votes,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = issue_id;
END//
DELIMITER ;

-- 뉴스 자동 분류 함수
DELIMITER //
CREATE FUNCTION classify_news_category(news_title TEXT, news_content TEXT)
RETURNS VARCHAR(50)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE result_category VARCHAR(50) DEFAULT '기타';
    DECLARE category_score INT DEFAULT 0;
    DECLARE max_score INT DEFAULT 0;
    DECLARE done INT DEFAULT FALSE;
    DECLARE cat_name VARCHAR(50);
    DECLARE keywords JSON;

    DECLARE category_cursor CURSOR FOR
        SELECT c.name, t.keyword_list
        FROM categories c
        LEFT JOIN tags t ON c.id = t.category_id
        WHERE c.is_active = TRUE;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN category_cursor;

    category_loop: LOOP
        FETCH category_cursor INTO cat_name, keywords;
        IF done THEN
            LEAVE category_loop;
        END IF;

        SET category_score = 0;

        -- 키워드 매칭 로직 (단순화)
        IF keywords IS NOT NULL THEN
            -- JSON 배열의 각 키워드를 확인
            IF LOWER(news_title) REGEXP LOWER(JSON_UNQUOTE(JSON_EXTRACT(keywords, '$[0]')))
               OR LOWER(news_content) REGEXP LOWER(JSON_UNQUOTE(JSON_EXTRACT(keywords, '$[0]'))) THEN
                SET category_score = category_score + 1;
            END IF;
        END IF;

        -- 카테고리명 직접 매칭
        IF LOWER(news_title) LIKE CONCAT('%', LOWER(cat_name), '%')
           OR LOWER(news_content) LIKE CONCAT('%', LOWER(cat_name), '%') THEN
            SET category_score = category_score + 2;
        END IF;

        IF category_score > max_score THEN
            SET max_score = category_score;
            SET result_category = cat_name;
        END IF;

    END LOOP;

    CLOSE category_cursor;

    RETURN result_category;
END//
DELIMITER ;

-- 뉴스 수집 스케줄링을 위한 이벤트 (선택사항)
-- SET GLOBAL event_scheduler = ON;
--
-- DELIMITER //
-- CREATE EVENT auto_collect_news
-- ON SCHEDULE EVERY 1 HOUR
-- DO
-- BEGIN
--     INSERT INTO news_collection_logs (job_type, parameters, started_at)
--     VALUES ('scheduled', '{"interval": "hourly"}', NOW());
--
--     -- 실제 뉴스 수집 로직은 애플리케이션에서 처리
-- END//
-- DELIMITER ;

-- 인덱스 최적화를 위한 추가 인덱스
CREATE INDEX idx_auto_collected_news_category_date ON auto_collected_news(auto_category, published_at DESC);
CREATE INDEX idx_issues_category_score ON issues(category, debate_score DESC);
CREATE INDEX idx_debatable_candidates_score ON debatable_issue_candidates(controversy_score DESC, status);

-- 전체 텍스트 검색을 위한 추가 인덱스
ALTER TABLE issues ADD FULLTEXT(title, summary) WITH PARSER ngram;
ALTER TABLE comments ADD FULLTEXT(content) WITH PARSER ngram;id (issue_id),
    INDEX idx_relevance_score (relevance_score DESC)
);

-- 기존 뉴스 테이블 (유지)
CREATE TABLE news (
    id INT AUTO_INCREMENT PRIMARY KEY,
    issue_id INT NOT NULL,
    stance ENUM('pro', 'con') NOT NULL,
    title VARCHAR(300) NOT NULL,
    summary TEXT NOT NULL,
    url TEXT NOT NULL,
    source VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (issue_id) REFERENCES issues(id) ON DELETE CASCADE,
    INDEX idx_issue_stance (issue_id, stance)
);

-- 카테고리 테이블
CREATE TABLE categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    icon VARCHAR(10),
    description TEXT,
    sort_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 태그 테이블
CREATE TABLE tags (
    id INT AUTO_INCREMENT PRIMARY KEY,
    category_id INT NOT NULL,
    name VARCHAR(50) NOT NULL,
    description TEXT,
    keyword_list JSON DEFAULT NULL,
    sort_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE,
    UNIQUE KEY unique_category_tag (category_id, name),
    INDEX idx_category_id (category_id)
);

-- 논쟁적 이슈 후보 테이블
CREATE TABLE debatable_issue_candidates (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(300) NOT NULL,
    summary TEXT,
    category VARCHAR(50),
    related_news_count INT DEFAULT 0,
    pro_news_count INT DEFAULT 0,
    con_news_count INT DEFAULT 0,
    controversy_score FLOAT DEFAULT 0.0,
    auto_generated_summary TEXT,
    status ENUM('pending', 'approved', 'rejected', 'converted') DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP NULL,
    converted_issue_id INT NULL,
    FOREIGN KEY (converted_issue_id) REFERENCES issues(id) ON DELETE SET NULL,
    INDEX idx_controversy_score (controversy_score DESC),
    INDEX idx_status (status),
    INDEX idx_created_at (created_at DESC)
);

-- 뉴스 수집 작업 로그 테이블
CREATE TABLE news_collection_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    job_type ENUM('scheduled', 'manual', 'category_specific', 'tag_specific') NOT NULL,
    parameters JSON DEFAULT NULL,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP NULL,
    status ENUM('running', 'completed', 'failed') DEFAULT 'running',
    news_collected_count INT DEFAULT 0,
    issues_generated_count INT DEFAULT 0,
    error_message TEXT,
    INDEX idx_started_at (started_at DESC),
    INDEX idx_status (status)
);

-- 기존 테이블들 (유지)
CREATE TABLE votes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    issue_id INT NOT NULL,
    user_id VARCHAR(255) NOT NULL,
    vote ENUM('pro', 'con') NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (issue_id) REFERENCES issues(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_vote (issue_id, user_id),
    INDEX idx_issue_