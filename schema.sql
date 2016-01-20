-- schema tables for forum
-- These be me dragons
DROP TABLE IF EXISTS posts;
DROP TABLE IF EXISTS topics;
DROP TABLE IF EXISTS users;

CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  name VARCHAR(20) NOT NULL,
  password_digest VARCHAR NOT NULL,
  email VARCHAR UNIQUE NOT NULL,
  real_name VARCHAR(50),
  about VARCHAR
);

CREATE TABLE topics (
  id SERIAL PRIMARY KEY,
  title VARCHAR(50) NOT NULL,
  content VARCHAR NOT NULL,
  upvotes INTEGER DEFAULT 0, 
  user_id INTEGER REFERENCES users(id)
);

CREATE TABLE posts (
  id SERIAL PRIMARY KEY,
  content VARCHAR NOT NULL,
  user_id INTEGER REFERENCES users(id),
  topics_id INTEGER REFERENCES topics(id)
);