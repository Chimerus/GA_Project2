-- schema tables for forum
-- These be me dragons
-- DROP TABLE IF EXISTS posts;
-- DROP TABLE IF EXISTS topics;
-- DROP TABLE IF EXISTS users;

CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  name VARCHAR(20) NOT NULL,
  password_digest VARCHAR NOT NULL,
  email VARCHAR UNIQUE NOT NULL,
  img_link VARCHAR DEFAULT NULL,
  real_name VARCHAR(50),
  about VARCHAR,
  created_at TIMESTAMP DEFAULT current_timestamp
);

CREATE TABLE topics (
  id SERIAL PRIMARY KEY,
  title VARCHAR(50) NOT NULL,
  content VARCHAR NOT NULL,
  upvotes INTEGER DEFAULT 0, 
  responses INTEGER DEFAULT 0, 
  user_id INTEGER REFERENCES users(id),
  is_review BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT current_timestamp,
  updated_at TIMESTAMP DEFAULT current_timestamp
);

CREATE TABLE posts (
  id SERIAL PRIMARY KEY,
  content VARCHAR NOT NULL,
  user_id INTEGER REFERENCES users(id),
  topics_id INTEGER REFERENCES topics(id),
  created_at TIMESTAMP DEFAULT current_timestamp,
  updated_at TIMESTAMP DEFAULT current_timestamp
);

-- come back to this sometime
-- to limit upvotes, join table
-- CREATE TABLE users_upvotes_posts (
--   user_id INTEGER REFERENCES users(id),
--   topics_id INTEGER REFERENCES topics(id)
-- );