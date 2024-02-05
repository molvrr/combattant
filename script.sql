CREATE TABLE clients (
  id SERIAL PRIMARY KEY,
  name VARCHAR(50) NOT NULL,
  limit INTEGER NOT NULL
);

CREATE TYPE transaction_type AS ENUM ('c', 'd');

CREATE TABLE transactions (
  id SERIAL PRIMARY KEY,
  client_id REFERENCES clients,
  value INTEGER NOT NULL,
  type transaction_type NOT NULL,
  description VARCHAR(10) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE balances (
  id SERIAL PRIMARY KEY,
  client_id REFERENCES clients,
  value INTEGER NOT NULL
);

BEGIN
  INSERT INTO clients (name, limit)
  VALUES
      ('naruto', 1000 * 100),
      ('mob', 800 * 100),
      ('jojo', 10000 * 100),
      ('hellboy', 5000 * 100);
  INSERT INTO balances (client_id, value)
      SELECT id, 0 FROM clients;
END;
