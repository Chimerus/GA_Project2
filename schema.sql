-- schema tables for forum
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  name VARCHAR(20) NOT NULL,
  password_digest VARCHAR NOT NULL,
  email VARCHAR UNIQUE NOT NULL
);

CREATE TABLE topics (
  id SERIAL PRIMARY KEY,
  title VARCHAR NOT NULL,
  content VARCHAR NOT NULL,
  upvotes INTEGER DEFAULT 0, 
  user_id INTEGER REFERENCES users(id)
);

CREATE TABLE posts (
  id SERIAL PRIMARY KEY,
  content VARCHAR NOT NULL,
  password_digest VARCHAR NOT NULL,
  email VARCHAR UNIQUE NOT NULL,
  user_id INTEGER REFERENCES users(id)
);