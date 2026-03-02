\c airline_db;

DROP TABLE IF EXISTS login_history CASCADE;
DROP TABLE IF EXISTS tickets CASCADE;
DROP TABLE IF EXISTS flights CASCADE;
DROP TABLE IF EXISTS passengers CASCADE;
DROP TABLE IF EXISTS aircrafts CASCADE;
DROP TABLE IF EXISTS users CASCADE;

CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('admin', 'operator')),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'blocked')),
    registration_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP
);

CREATE INDEX idx_users_username ON users(username);

CREATE TABLE aircrafts (
    aircraft_id SERIAL PRIMARY KEY,
    model VARCHAR(100) NOT NULL,
    registration_number VARCHAR(20) UNIQUE NOT NULL,
    capacity INTEGER NOT NULL CHECK (capacity > 0),
    manufacture_year INTEGER CHECK (manufacture_year BETWEEN 1900 AND EXTRACT(YEAR FROM CURRENT_DATE)),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'maintenance', 'retired'))
);

CREATE INDEX idx_aircrafts_model ON aircrafts(model);

CREATE TABLE flights (
    flight_id SERIAL PRIMARY KEY,
    flight_number VARCHAR(10) UNIQUE NOT NULL,
    aircraft_id INTEGER NOT NULL REFERENCES aircrafts(aircraft_id) ON DELETE RESTRICT,
    departure_city VARCHAR(50) NOT NULL,
    arrival_city VARCHAR(50) NOT NULL,
    departure_date DATE NOT NULL,
    departure_time TIME NOT NULL,
    arrival_date DATE NOT NULL,
    arrival_time TIME NOT NULL,
    ticket_price DECIMAL(10,2) NOT NULL CHECK (ticket_price > 0),
    status VARCHAR(20) DEFAULT 'scheduled' 
        CHECK (status IN ('scheduled', 'delayed', 'cancelled', 'departed', 'arrived')),
    available_seats INTEGER NOT NULL CHECK (available_seats > 0),

    CHECK ((arrival_date > departure_date) OR 
           (arrival_date = departure_date AND arrival_time > departure_time))
);

CREATE INDEX idx_flights_route ON flights(departure_city, arrival_city);
CREATE INDEX idx_flights_date ON flights(departure_date);
CREATE INDEX idx_flights_number ON flights(flight_number);

CREATE TABLE passengers (
    passenger_id SERIAL PRIMARY KEY,
    last_name VARCHAR(50) NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    middle_name VARCHAR(50),
    passport_number VARCHAR(20) UNIQUE NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(100),
    registration_date DATE DEFAULT CURRENT_DATE,

    CHECK (email IS NULL OR email LIKE '%@%.%')
);

CREATE INDEX idx_passengers_name ON passengers(last_name, first_name);
CREATE INDEX idx_passengers_passport ON passengers(passport_number);
CREATE INDEX idx_passengers_phone ON passengers(phone);

CREATE TABLE tickets (
    ticket_id SERIAL PRIMARY KEY,
    flight_id INTEGER NOT NULL REFERENCES flights(flight_id) ON DELETE CASCADE,
    passenger_id INTEGER NOT NULL REFERENCES passengers(passenger_id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(user_id),
    seat_number VARCHAR(5) NOT NULL,
    price DECIMAL(10,2) NOT NULL CHECK (price > 0),
    booking_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'booked' 
        CHECK (status IN ('booked', 'refunded', 'exchanged', 'used')),

    UNIQUE(flight_id, seat_number)
);

CREATE INDEX idx_tickets_flight ON tickets(flight_id);
CREATE INDEX idx_tickets_passenger ON tickets(passenger_id);
CREATE INDEX idx_tickets_date ON tickets(booking_date);

CREATE TABLE login_history (
    history_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    login_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address VARCHAR(45),
    result VARCHAR(20) CHECK (result IN ('success', 'failed'))
);

CREATE INDEX idx_login_history_user ON login_history(user_id);

INSERT INTO users (username, password_hash, role, status) VALUES
('admin', 'admin123', 'admin', 'active'),
('operator1', 'oper123', 'operator', 'active'),
('operator2', 'oper456', 'operator', 'blocked');

INSERT INTO aircrafts (model, registration_number, capacity, manufacture_year) VALUES
('Boeing 737-800', 'RA-12345', 189, 2015),
('Airbus A320', 'RA-67890', 180, 2018),
('Boeing 777-300', 'RA-54321', 350, 2020);

INSERT INTO flights (flight_number, aircraft_id, departure_city, arrival_city, 
                   departure_date, departure_time, arrival_date, arrival_time, 
                   ticket_price, status, available_seats) VALUES
('SU-100', 1, 'Москва (SVO)', 'Нью-Йорк (JFK)', 
 '2025-03-15', '10:00', '2025-03-15', '22:00', 25000, 'scheduled', 189),
('SU-101', 1, 'Нью-Йорк (JFK)', 'Москва (SVO)', 
 '2025-03-16', '12:00', '2025-03-17', '06:00', 27000, 'scheduled', 189),
('S7-250', 2, 'Москва (DME)', 'Санкт-Петербург (LED)', 
 '2025-03-16', '14:30', '2025-03-16', '16:00', 8000, 'scheduled', 180);

INSERT INTO passengers (last_name, first_name, middle_name, passport_number, phone, email) VALUES
('Иванов', 'Иван', 'Иванович', '1234 567890', '+7-916-111-22-33', 'ivan@mail.ru'),
('Петрова', 'Мария', 'Сергеевна', '0987 654321', '+7-926-222-33-44', 'maria@gmail.com'),
('Сидоров', 'Алексей', 'Петрович', '4567 890123', '+7-903-333-44-55', 'alex@yandex.ru');

INSERT INTO tickets (flight_id, passenger_id, user_id, seat_number, price) VALUES
(1, 1, 1, '15A', 25000),
(1, 2, 2, '15B', 25000),
(2, 3, 1, '1A', 27000);

SELECT * FROM flights;

SELECT p.last_name, p.first_name, f.flight_number, t.seat_number, t.price
FROM passengers p
JOIN tickets t ON p.passenger_id = t.passenger_id
JOIN flights f ON t.flight_id = f.flight_id;

SELECT 
    f.flight_number,
    f.available_seats AS total_seats,
    COUNT(t.ticket_id) AS sold_seats,
    f.available_seats - COUNT(t.ticket_id) AS free_seats
FROM flights f
LEFT JOIN tickets t ON f.flight_id = t.flight_id
GROUP BY f.flight_id;

SELECT 
    u.username,
    u.role,
    u.status,
    COUNT(DISTINCT t.ticket_id) AS tickets_sold
FROM users u
LEFT JOIN tickets t ON u.user_id = t.user_id
GROUP BY u.user_id;