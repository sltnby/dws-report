
-- -- -- -- -- -- -- -- -- -- -- -- --
## SEMESTER REPORT ##
-- -- -- -- -- -- -- -- -- -- -- -- --


-- -- -- -- -- -- -- -- --
## Creating a Database ##
-- -- -- -- -- -- -- -- --

CREATE DATABASE DWS_Report;

-- -- -- -- -- -- -- --
## Creating Tables ##
-- -- -- -- -- -- -- --

## Locations ##
CREATE TABLE locations(
postal_code VARCHAR(5) PRIMARY KEY,
city VARCHAR(50) NOT NULL,
state ENUM('Berlin', 'Hamburg', 'Brandenburg') NOT NULL
);


## Customers ##
CREATE TABLE customers(
customer_id INT PRIMARY KEY,           
first_name VARCHAR(100) NOT NULL,
last_name VARCHAR(100) NOT NULL,
telephone VARCHAR(50) NOT NULL UNIQUE,
email VARCHAR(75) NOT NULL UNIQUE,
address VARCHAR(200),
postal_code VARCHAR(5),
FOREIGN KEY(postal_code) REFERENCES locations(postal_code)
);

## Warehouses ##
CREATE TABLE warehouses(
warehouse_id INT PRIMARY KEY,
warehouse_name VARCHAR(100) NOT NULL UNIQUE,
address VARCHAR(200),
postal_code VARCHAR(5),
FOREIGN KEY (postal_code) REFERENCES locations(postal_code)
);

## Company Teams ##
CREATE TABLE teams(
team_id INT PRIMARY KEY,
team_name VARCHAR(50) NOT NULL UNIQUE,
team_type ENUM('Sales', 'HR', 'IT', 'Logistics') NOT NULL, # Making sure that no other team type is accidentaly entered
postal_code VARCHAR(5) NOT NULL,  
warehouse_id INT,										   # Making sure that we link the logistics employees to the correct warehouse
FOREIGN KEY(warehouse_id) REFERENCES warehouses(warehouse_id),
FOREIGN KEY(postal_code) REFERENCES locations(postal_code)
);

## Employees ##
CREATE TABLE employees(
employee_id INT PRIMARY KEY,
first_name VARCHAR(100) NOT NULL,
last_name VARCHAR(100) NOT NULL,
telephone VARCHAR(50) NOT NULL UNIQUE,
email VARCHAR(75) NOT NULL UNIQUE,
address VARCHAR(200),
postal_code VARCHAR(5),
team_id INT NOT NULL,
FOREIGN KEY (team_id) REFERENCES teams(team_id),
FOREIGN KEY (postal_code) REFERENCES locations(postal_code)             # CREATE A LINK BETWEEN SALES AND EMPLOYEE
);

## Product Departments ##
CREATE TABLE prod_department(
department_id INT PRIMARY KEY,
department_name VARCHAR(50) UNIQUE NOT NULL
);

## Products ##
CREATE TABLE products(
product_id INT PRIMARY KEY,
product_name VARCHAR(100) NOT NULL,
department_id INT NOT NULL,
unit_price DECIMAL(18,2) NOT NULL,
FOREIGN KEY(department_id) REFERENCES prod_department(department_id)
);

## Order Status ##
CREATE TABLE order_status(
current_status VARCHAR(50) PRIMARY KEY
);

## Orders ##
CREATE TABLE orders(
order_id INT PRIMARY KEY,
customer_id INT NOT NULL,
created_at DATETIME NOT NULL,
updated_at DATETIME,
current_status VARCHAR(50) NOT NULL,
employee_id INT NOT NULL,  											# Connects the sales to the employee
FOREIGN KEY(customer_id) REFERENCES customers(customer_id),
FOREIGN KEY(current_status) REFERENCES order_status(current_status),
FOREIGN KEY(employee_id) REFERENCES employees(employee_id)
);

## Order Items ##
# First many-to-many relationship: Product and Order
CREATE TABLE orderitems(
orderitem_id INT PRIMARY KEY,  # we make sure that the product that is return was already in the order
order_id INT NOT NULL,
product_id INT NOT NULL,
quantity INT NOT NULL,
unit_price DECIMAL(18,2) NOT NULL,
FOREIGN KEY(order_id) REFERENCES orders(order_id),
FOREIGN KEY(product_id) REFERENCES products(product_id),
UNIQUE(order_id, product_id)
);



## Inventory ##
# Second many-to-many relationship: Warehouse and Product
CREATE TABLE inventory(
product_id INT NOT NULL,
warehouse_id INT NOT NULL,
quantity_on_hand INT NOT NULL DEFAULT 0,
reorder_threshold INT NOT NULL,
updated_at DATETIME,
PRIMARY KEY(product_id, warehouse_id),
FOREIGN KEY(product_id) REFERENCES products(product_id),
FOREIGN KEY(warehouse_id) REFERENCES warehouses(warehouse_id)
);

## Payment Status ##
CREATE TABLE payment_status(
current_status VARCHAR(50) PRIMARY KEY
);

## Payments ##
CREATE TABLE payments(
payment_id INT PRIMARY KEY,
order_id INT NOT NULL,
payment_method VARCHAR(50) NOT NULL,
created_at DATETIME NOT NULL,
updated_at DATETIME,
amount DECIMAL(18,2) NOT NULL,
current_status VARCHAR(50) NOT NULL,
FOREIGN KEY(order_id) REFERENCES orders(order_id),
FOREIGN KEY(current_status) REFERENCES payment_status(current_status)
);

## Shipment Status ##
CREATE TABLE shipment_status(
current_status VARCHAR(50) PRIMARY KEY
);

## Shipment ##
CREATE TABLE shipments(
shipment_id INT PRIMARY KEY,
order_id INT NOT NULL,
warehouse_id INT NOT NULL,
current_status VARCHAR(50) NOT NULL,
created_at DATETIME NOT NULL,
updated_at DATETIME,
delivered_at DATETIME,
FOREIGN KEY(order_id) REFERENCES orders(order_id),
FOREIGN KEY(warehouse_id) REFERENCES warehouses(warehouse_id),
FOREIGN KEY(current_status) REFERENCES shipment_status(current_status)
);

## Product Reviews ##
CREATE TABLE reviews(
review_id INT PRIMARY KEY,
customer_id INT NOT NULL,
product_id INT NOT NULL,
rating INT NOT NULL,
review_comment TEXT,
created_at DATETIME NOT NULL,
updated_at DATETIME NOT NULL,
UNIQUE(customer_id, product_id),
FOREIGN KEY(product_id) REFERENCES products(product_id),              
FOREIGN KEY(customer_id) REFERENCES customers(customer_id),
CHECK(rating BETWEEN 1 AND 5)
);

## Return Status ##
CREATE TABLE return_status(
return_status VARCHAR(50) PRIMARY KEY
);

## Returns ##
CREATE TABLE returns(
return_id INT PRIMARY KEY,
order_id INT NOT NULL UNIQUE,
warehouse_id INT NOT NULL,
created_at DATETIME NOT NULL,
updated_at DATETIME,
return_status VARCHAR(50) NOT NULL,
refund_amount DECIMAL(18,2),
FOREIGN KEY(order_id) REFERENCES orders(order_id),
FOREIGN KEY(return_status) REFERENCES return_status(return_status),
FOREIGN KEY(warehouse_id) REFERENCES warehouses(warehouse_id)
);

## Return Items ##
# Third many-to-many relationship: Returns and Products
CREATE TABLE returnitems(
return_id INT NOT NULL,
orderitem_id INT NOT NULL,
quantity INT NOT NULL,
reason VARCHAR(200),
PRIMARY KEY(return_id, orderitem_id),
FOREIGN KEY(return_id) REFERENCES returns(return_id),
FOREIGN KEY(orderitem_id) REFERENCES orderitems(orderitem_id) # we make sure that the product that is return was already in the order
);

-- -- -- -- -- -- -- --
##  Adding a Trigger ##
-- -- -- -- -- -- -- --

# This is to ensure the customer doesn't return more items that that was already in the order.

DELIMITER //

CREATE TRIGGER validate_return_quality
BEFORE INSERT ON returnitems
FOR EACH ROW
BEGIN
	DECLARE ordered_qty INT;
    
    #Get the og quantity from the order
    SELECT quantity
    INTO ordered_qty
    FROM orderitems
    WHERE orderitem_id = NEW.orderitem_id;
    
    #Create the trigger if the return quantity exceeds og quantity
    IF NEW.quantity > ordered_qty THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = 'Return quantity must not exceed the original quantity!';
	END IF;
END; //

DELIMITER ;

-- -- -- -- -- -- -- --
## Creating Values ##
-- -- -- -- -- -- -- --

INSERT INTO locations (postal_code, city, state)
VALUES
('10115', 'Berlin', 'Berlin'),
('20095', 'Hamburg', 'Hamburg'),
('14467', 'Potsdam', 'Brandenburg');

INSERT INTO customers (customer_id, first_name, last_name, telephone, email, postal_code)
VALUES
(1, 'Hans', 'G', '01-1', 'h@m.de', '10115'), (2, 'Klaus', 'D', '01-2', 'k@m.de', '20095'),
(3, 'Petra', 'V', '01-3', 'p@m.de', '14467'), (4, 'Otto', 'K', '01-4', 'o@m.de', '10115'),
(5, 'Marta', 'L', '01-5', 'm@m.de', '20095'), (6, 'Uwe', 'S', '01-6', 'u@m.de', '20095'),
(7, 'Berti', 'V', '01-7', 'b@m.de', '14467'), (8, 'Lothar', 'M', '01-8', 'l@m.de', '10115'),
(9, 'Rudi', 'V', '01-9', 'r@m.de', '14467'), (10, 'Silke', 'R', '01-10', 's@m.de', '10115'),
(11, 'Oliver', 'B', '01-11', 'ol@m.de', '20095'), (12, 'Toni', 'K', '01-12', 't@m.de', '14467'),
(13, 'Marco', 'R', '01-13', 'ma@m.de', '10115'), (14, 'Thomas', 'M', '01-14', 'th@m.de', '20095'),
(15, 'Manuel', 'N', '01-15', 'man@m.de', '10115'), (16, 'Joshua', 'K', '01-16', 'j@m.de', '14467'),
(17, 'Leroy', 'S', '01-17', 'le@m.de', '20095'), (18, 'Serge', 'G', '01-18', 'se@m.de', '10115'),
(19, 'Kai', 'H', '01-19', 'ka@m.de', '14467'), (20, 'Leon', 'G', '01-20', 'leo@m.de', '10115');

INSERT INTO warehouses (warehouse_id, warehouse_name, address, postal_code)
VALUES
(1, 'Berlin Central Hub', 'Heidestraße 42', '10115'),
(2, 'Hamburg Port Logistik', 'Am Sandtorkai 10', '20095'),
(3, 'Brandenburg Park', 'An der Autobahn 1', '14467');

INSERT INTO teams (team_id, team_name, team_type, postal_code, warehouse_id)
VALUES
(1, 'Sales Berlin', 'Sales', '10115', NULL),
(2, 'Logistics Berlin', 'Logistics', '10115', 1),
(3, 'Sales Hamburg', 'Sales', '20095', NULL),
(4, 'Logistics Hamburg', 'Logistics', '20095', 2),
(5, 'Sales Brandenburg', 'Sales', '14467', NULL),
(6, 'Logistics Brandenburg', 'Logistics', '14467', 3),
(7, 'HR National', 'HR', '10115', NULL),
(8, 'IT National', 'IT', '10115', NULL);

INSERT INTO employees (employee_id, first_name, last_name, telephone, email, postal_code, team_id)
VALUES
(1, 'Lukas', 'Müller', '030-101', 'l.m@co.de', 10115, 1),
(2, 'Emma', 'Schmidt', '030-102', 'e.s@co.de', 10115, 2),
(3, 'Finn', 'Fischer', '040-103', 'f.f@co.de', 20095, 3),
(4, 'Leon', 'Weber', '040-104', 'l.w@co.de', 20095, 4),
(5, 'Mia', 'Meyer', '0331-105', 'm.m@co.de', 14467, 5),
(6, 'Noah', 'Wagner', '0331-106', 'n.w@co.de', 14467, 6),
(7, 'Hannah', 'Becker', '030-107', 'h.b@co.de', 10115, 7),
(8, 'Elias', 'Schulz', '030-108', 'e.sch@co.de', 10115, 8),
(9, 'Sofia', 'Hoffmann', '030-109', 's.h@co.de', 10115, 1),
(10, 'Ben', 'Schäfer', '040-110', 'b.s@co.de', 20095, 3),
(11, 'Lina', 'Koch', '0331-111', 'l.k@co.de', 14467, 5),
(12, 'Luis', 'Bauer', '030-112', 'l.b@co.de', 10115, 8);

INSERT INTO prod_department (department_id, department_name)
VALUES
(1, 'Tech'),
(2, 'Office'),
(3, 'Software'),
(4, 'Mobile'),
(5, 'Audio');

INSERT INTO products (product_id, product_name, department_id, unit_price)
VALUES
(1, 'Laptop Pro', 1, 1200.00),
(2, 'Desktop PC', 1, 900.00),
(3, 'Office Desk', 2, 450.00),
(4, 'Ergo Chair', 2, 350.00),
(5, 'OS License', 3, 150.00),
(6, 'Antivirus', 3, 50.00),
(7, 'Smartphone', 4, 800.00),
(8, 'Tablet', 4, 400.00),
(9, 'Headset', 5, 80.00),
(10, 'Speakers', 5, 120.00),
(11, 'Monitor 4K', 1, 500.00),
(12, 'Keyboard', 5, 100.00),
(13, 'Mouse', 5, 40.00),
(14, 'Webcam', 1, 60.00);

INSERT INTO order_status (current_status)
VALUES
('Pending'),
('Shipped'),
('Delivered'),
('Cancelled');

INSERT INTO orders (order_id, customer_id, created_at, current_status, employee_id)
VALUES
(1,1,'2025-12-01 10:30:00','Delivered',1),
(2,2,'2025-12-05 14:20:00','Delivered',3),
(3,3,'2025-12-10 09:15:00','Delivered',5),
(4,4,'2025-12-15 16:45:00','Delivered',9),
(5,5,'2025-12-20 11:00:00','Delivered',10),
(6,6,'2025-12-24 10:00:00','Shipped',3),
(7,7,'2025-12-27 13:00:00','Pending',11),
(8,8,'2025-12-30 15:30:00','Delivered',1),
(9,9,'2026-01-02 08:45:00','Delivered',5),
(10,10,'2026-01-03 12:00:00','Cancelled',9),
(11,11,'2026-01-04 14:10:00','Delivered',10),
(12,12,'2026-01-05 11:20:00','Delivered',11),
(13,13,'2026-01-05 15:50:00','Shipped',1),
(14,14,'2026-01-06 09:30:00','Pending',3),
(15,15,'2026-01-06 14:00:00','Delivered',9),
(16,16,'2026-01-07 10:20:00','Delivered',5),
(17,17,'2026-01-07 16:40:00','Shipped',10),
(18,18,'2026-01-08 11:15:00','Pending',1),
(19,19,'2026-01-08 13:45:00','Delivered',11),
(20,20,'2026-01-09 10:00:00','Delivered',9),
(21, 1, '2026-01-10 09:00:00', 'Delivered', 1),
(22, 5, '2026-01-12 14:30:00', 'Delivered', 10),
(23, 9, '2026-01-15 11:20:00', 'Shipped', 5),
(24, 1, '2026-02-01 10:00:00', 'Delivered', 3),
(25, 11, '2026-02-05 16:00:00', 'Delivered', 10),
(26, 1, '2026-01-26 10:00:00', 'Pending', 1),
(27, 2, '2026-01-26 14:00:00', 'Pending', 3),
(28, 3, '2026-01-26 16:30:00', 'Delivered', 5),
(29, 10, '2026-01-27 09:00:00', 'Shipped', 9),
(30, 15, '2026-01-27 11:00:00', 'Pending', 1);

INSERT INTO orderitems (orderitem_id, order_id, product_id, quantity, unit_price)
VALUES
(1,1,1,1,1200.00),(2,2,3,1,450.00),
(3,3,5,1,150.00), (4,4,9,1,80.00),
(5,5,7,1,800.00), (6,6,8,1,400.00),
(7,7,11,1,500.00), (8,8,12,1,100.00),
(9,9,13,1,40.00), (10,10,14,1,60.00),
(11,11,1,1,1200.00), (12,12,2,1,900.00),
(13,13,3,1,450.00), (14,14,4,1,350.00),
(15,15,5,1,150.00), (16,16,6,1,50.00),
(17,17,7,1,800.00), (18,18,8,1,400.00),
(19,19,9,1,80.00), (20,20,10,1,120.00),
(21, 21, 1, 2, 1200.00), (22, 22, 2, 1, 45.00),
(23, 23, 3, 5, 450.00), (24, 24, 1, 1, 120.00),
(25, 25, 4, 3, 60.00), (26, 26, 1, 1, 1200.00),
(27, 26, 7, 2, 800.00), (28,26, 11, 2, 500.00),
(29, 27, 2, 1, 900.00), (30, 27, 3, 1, 450.00),
(31, 27, 4, 1, 350.00), (32, 27, 11, 2, 500.00),
(33, 28, 5, 5, 150.00), (34, 28, 6, 5, 50.00),
(35, 29, 7, 1, 800.00), (36, 29, 9, 1, 80.00),
(37, 29, 14, 1, 60.00), (38, 30, 12, 10, 100.00),
(39, 30, 13, 10, 40.00);

INSERT INTO inventory (product_id, warehouse_id, quantity_on_hand, reorder_threshold, updated_at)
VALUES
(1,1,15,20,'2026-01-01'), (2,1,85,20,'2026-01-02'), (3,1,9,10,'2026-01-03'), (4,1,15,5,'2026-01-04'),
(5,1,25,10,'2026-01-05'), (6,1,30,25,'2026-01-06'), (7,1,45,15,'2026-01-07'), (8,1,12,15,'2026-01-08'),
(9,1,40,15,'2026-01-09'), (10,1,22,10,'2026-01-09'), (11,1,60,20,'2026-01-09'), (12,1,5,10,'2026-01-09'),
(13,1,12,15,'2026-01-09'), (14,1,56,40,'2026-01-09'), (1,2,14,15,'2026-01-05'), (2,2,20,5,'2026-01-05'),
(3,3,100,20,'2026-01-08'), (4,3,18,5,'2026-01-08'), (7,2,8,10,'2026-01-07'), (8,3,4,5,'2026-01-08');

INSERT INTO payment_status (current_status)
VALUES
('Unpaid'),
('Paid'),
('Refunded');

INSERT INTO payments (payment_id, order_id, payment_method, created_at, amount, current_status)
VALUES
(1,1,'CC','2025-12-01 10:35:00',1200.00,'Paid'),
(2,2,'PP','2025-12-05 14:45:00',450.00,'Paid'),
(3,3,'Bank','2025-12-10 10:00:00',150.00,'Paid'),
(4,4,'CC','2025-12-15 16:50:00',80.00,'Paid'),
(5,5,'PP','2025-12-20 11:05:00',800.00,'Paid'),
(6,6,'CC','2025-12-24 10:15:00',400.00,'Paid'),
(7,7,'Bank','2025-12-27 13:10:00',500.00,'Unpaid'),
(8,8,'CC','2025-12-30 15:45:00',100.00,'Paid'),
(9,9,'PP','2026-01-02 09:00:00',40.00,'Paid'),
(10,10,'CC','2026-01-03 12:30:00',60.00,'Refunded'),
(11,11,'CC','2026-01-04 14:20:00',1200.00,'Paid'),
(12,12,'PP','2026-01-05 11:30:00',900.00,'Paid'),
(13,13,'Bank','2026-01-05 16:00:00',450.00,'Paid'),
(14,14,'CC','2026-01-06 09:45:00',350.00,'Unpaid'),
(15,15,'PP','2026-01-06 14:10:00',150.00,'Paid'),
(16,16,'CC','2026-01-07 10:30:00',50.00,'Paid'),
(17,17,'Bank','2026-01-07 17:00:00',800.00,'Paid'),
(18,18,'PP','2026-01-08 11:30:00',400.00,'Paid'),
(19,19,'CC','2026-01-08 14:00:00',80.00,'Paid'),
(20,20,'PP','2026-01-09 10:15:00',120.00,'Paid'),
(21, 26, 'CC', '2026-01-26 10:05:00', 3000.00, 'Paid'),
(22, 27, 'Bank', '2026-01-26 14:15:00', 2700.00, 'Unpaid'),
(23, 28, 'PP', '2026-01-26 16:35:00', 1000.00, 'Paid'),
(24, 29, 'CC', '2026-01-27 09:10:00', 940.00, 'Paid'),
(25, 30, 'Bank', '2026-01-27 11:05:00', 1400.00, 'Paid');

INSERT INTO shipment_status (current_status)
VALUES
('In Warehouse'),
('Picked'),
('In Transit'),
('Delivered'),
('Returned');

INSERT INTO shipments (shipment_id, order_id, warehouse_id, current_status, created_at)
VALUES
(1,1,1,'Delivered','2025-12-02'), (2,2,2,'Delivered','2025-12-06'),
(3,3,3,'Delivered','2025-12-11'), (4,4,1,'Delivered','2025-12-16'),
(5,5,2,'Delivered','2025-12-21'), (6,6,2,'Returned','2025-12-25'),
(7,7,3,'In Warehouse','2025-12-28'), (8,8,1,'Delivered','2025-12-31'),
(9,9,3,'Delivered','2026-01-03'), (10,10,1,'In Warehouse','2026-01-04'),
(11,11,2,'Delivered','2026-01-05'), (12,12,3,'Delivered','2026-01-06'),
(13,13,1,'In Transit','2026-01-06'), (14,14,2,'In Warehouse','2026-01-07'),
(15,15,1,'Delivered','2026-01-07'), (16,16,3,'Delivered','2026-01-08'),
(17,17,2,'In Transit','2026-01-08'), (18,18,1,'In Warehouse','2026-01-09'),
(19,19,3,'Delivered','2026-01-09'), (20,20,1,'Delivered','2026-01-09'),
(21, 26, 1, 'In Warehouse', '2026-01-26'), (22, 27, 2, 'In Warehouse', '2026-01-26 15:00:00'),
(23, 28, 3, 'Delivered', '2026-01-26 16:30:00'),
(24, 29, 1, 'In Transit', '2026-01-27 11:00:00'), (25, 30, 1, 'In Warehouse', '2026-01-27 12:00:00');

UPDATE shipments SET delivered_at = '2026-01-26 16:40:00' WHERE shipment_id = 23;
UPDATE shipments SET delivered_at = '2025-12-05 09:00:00' WHERE shipment_id = 1;
UPDATE shipments SET delivered_at = '2025-12-09 10:00:00' WHERE shipment_id = 2;
UPDATE shipments SET delivered_at = '2025-12-15 11:00:00' WHERE shipment_id = 3;
UPDATE shipments SET delivered_at = '2025-12-18 09:00:00' WHERE shipment_id = 4;
UPDATE shipments SET delivered_at = '2025-12-26 14:00:00' WHERE shipment_id = 5;
UPDATE shipments SET delivered_at = '2026-01-04 11:00:00' WHERE shipment_id = 8;
UPDATE shipments SET delivered_at = '2026-01-07 10:34:00' WHERE shipment_id = 9;
UPDATE shipments SET delivered_at = '2026-01-10 13:45:00' WHERE shipment_id = 11;
UPDATE shipments SET delivered_at = '2026-01-10 11:21:00' WHERE shipment_id = 12;
UPDATE shipments SET delivered_at = '2026-01-11 15:21:00' WHERE shipment_id = 15;
UPDATE shipments SET delivered_at = '2026-01-09 09:19:00' WHERE shipment_id = 16;
UPDATE shipments SET delivered_at = '2026-01-11 12:05:00' WHERE shipment_id = 19;
UPDATE shipments SET delivered_at = '2026-01-15 15:43:00' WHERE shipment_id = 20;


INSERT INTO reviews (review_id, customer_id, product_id, rating, review_comment, created_at, updated_at)
VALUES
(1, 1, 1, 5, 'Great!', '2025-12-05 09:00:00', '2025-12-05 09:00:00'),
(2, 2, 3, 4, 'Solid', '2025-12-10 14:00:00', '2025-12-10 14:00:00'),
(3, 11, 1, 5, 'Perfekt!', '2026-01-08 12:00:00', '2026-01-08 12:00:00'),
(4, 15, 5, 3, 'Okay', '2026-01-09 11:00:00', '2026-01-09 11:00:00'),
(5, 4, 9, 1, 'Headset broke after two days. Very poor build quality.', '2025-12-20 09:30:00', '2025-12-20 09:30:00'),
(6, 8, 12, 2, 'Keyboard is missing the Euro symbol key. Not as described.', '2026-01-05 15:00:00', '2026-01-05 15:00:00'),
(7, 12, 2, 3, 'Desktop PC is fast, but the fan is extremely loud.', '2026-01-08 10:45:00', '2026-01-08 10:45:00'),
(8, 19, 9, 1, 'Delivery was fast but the package was crushed. Product damaged.', '2026-01-09 16:00:00', '2026-01-09 16:00:00');

INSERT INTO return_status (return_status)
VALUES
('Requested'), ('Received'), ('Inspected'), ('Refunded'), ('Rejected');

INSERT INTO returns (return_id, order_id, warehouse_id, created_at, return_status, refund_amount)
VALUES
(2, 4, 1, '2025-12-21 14:00:00', 'Refunded', 80.00),
(3, 10, 1, '2026-01-04 09:00:00', 'Received', 60.00),
(4, 8, 1, '2026-01-06 11:00:00', 'Requested', 100.00),
(5, 19, 3, '2026-01-09 15:30:00', 'Requested', 80.00),
(6, 6, 2, '2025-12-28 10:00:00', 'Refunded', 400.00);

INSERT INTO returnitems (return_id, orderitem_id, quantity, reason)
VALUES
(2, 4, 1, 'Defective - build quality issues'),
(3, 10, 1, 'Order cancelled by customer'),
(4, 8, 1, 'Product not as described - missing keys'),
(5, 19, 1, 'Shipping damage - package crushed'),
(6, 6, 1, 'Customer changed mind');

-- -- -- -- -- -- -- --
## Views ##
-- -- -- -- -- -- -- --

## Overall Departmental Sales ##

CREATE VIEW view_department_sales AS
SELECT
d.department_name,
COUNT(oi.orderitem_id) AS total_items_sold,
COALESCE(SUM(oi.quantity), 0) AS total_quantity,
COALESCE(SUM(oi.quantity * oi.unit_price), 0) AS total_revenue,
COALESCE(ROUND(AVG(oi.unit_price), 2), 0) AS avg_item_price
FROM prod_department d
LEFT JOIN products p ON d.department_id = p.department_id
LEFT JOIN orderitems oi ON p.product_id = oi.product_id
LEFT JOIN orders o ON oi.order_id = o.order_id
	AND o.current_status != 'Cancelled'
GROUP BY d.department_name;

SELECT *
FROM view_department_sales;

## Monthly Sales Performance ##

CREATE VIEW view_monthly_performance AS
SELECT
DATE_FORMAT(o.created_at, '%Y-%m') AS sales_month,
COUNT(DISTINCT o.order_id) AS total_orders,
SUM(oi.quantity * oi.unit_price) AS monthly_revenue,
COUNT(DISTINCT o.customer_id) AS unique_customers_served,
(SUM(oi.quantity * oi.unit_price) / COUNT(DISTINCT o.order_id))AS avg_order_value
FROM orders o
JOIN orderitems oi ON o.order_id = oi.order_id
WHERE o.current_status != 'Cancelled'
    GROUP BY sales_month
    ORDER BY sales_month DESC;
    
SELECT *
FROM view_monthly_performance;

## Low Stock Tracker ##

-- Showing which item's stock is below the reorder thresholdmo

CREATE VIEW view_low_stock_tracker AS
SELECT
p.product_name,
w.warehouse_name,
i.quantity_on_hand,
(i.reorder_threshold - i.quantity_on_hand) AS shortage_amount
FROM inventory i
JOIN warehouses w ON i.warehouse_id = w.warehouse_id
JOIN products p ON i.product_id = p.product_id
WHERE i.quantity_on_hand < i.reorder_threshold
ORDER BY shortage_amount DESC;

SELECT *
FROM view_low_stock_tracker;

## Sales Leaderboard ##

-- Showing which teams bring more sales

CREATE VIEW view_teams_leaderboard AS
SELECT
t.team_name,
COUNT(DISTINCT o.order_id) AS total_orders,
SUM(oi.quantity * oi.unit_price) AS total_revenue
FROM orders o
JOIN employees e ON o.employee_id = e.employee_id
JOIN orderitems oi ON o.order_id = oi.order_id
JOIN teams t on t.team_id = e.team_id
WHERE
t.team_type = 'Sales'
AND
o.current_status != 'Cancelled'
GROUP BY t.team_name
ORDER BY total_revenue DESC;

SELECT *
FROM view_teams_leaderboard;

-- -- -- -- -- -- -- --
## Queries ##
-- -- -- -- -- -- -- --

-- Performance Ranking --

SELECT
RANK() OVER(
	ORDER BY SUM(oi.quantity * oi.unit_price) DESC
    ) AS overall_rank,
t.team_name,
CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
SUM(oi.quantity * oi.unit_price) AS total_revenue,
RANK() OVER(
	PARTITION BY t.team_name
    ORDER BY SUM(oi.quantity * oi.unit_price) DESC
    ) AS team_rank
FROM orders o
JOIN employees e ON e.employee_id = o.employee_id
JOIN teams t ON e.team_id = t.team_id
JOIN orderitems oi ON o.order_id = oi.order_id
WHERE o.current_status != 'Cancelled'
GROUP BY t.team_name, employee_name
ORDER BY overall_rank;

-- High Return Value Analysis --

SELECT
r.return_id,
r.order_id,
SUM(ri.quantity) AS total_items_returned,
refund_amount,
CASE
	WHEN refund_amount > 350 OR SUM(ri.quantity) >= 10 THEN 'Critical Loss'
	WHEN refund_amount > 50 OR SUM(ri.quantity) >= 5 THEN 'Significant'
	ELSE 'Minor'
END AS impact_level
FROM returns AS r
JOIN returnitems AS ri ON r.return_id = ri.return_id
GROUP BY r.return_id, r.order_id, r.refund_amount
HAVING r.refund_amount > (SELECT AVG(refund_amount) FROM returns)
ORDER BY r.refund_amount DESC;

-- Departmental Revenue by Region --

SELECT
l.postal_code,
pd.department_name,
SUM(oi.quantity * oi.unit_price) AS regional_revenue
FROM orders o
JOIN employees AS e ON e.employee_id = o.employee_id
JOIN locations AS l ON e.postal_code = l.postal_code
JOIN orderitems oi ON o.order_id = oi.order_id
JOIN products p ON p.product_id = oi.product_id
JOIN prod_department pd ON p.department_id = pd.department_id
WHERE o.current_status != 'Cancelled'
GROUP BY l.postal_code, pd.department_name
ORDER BY regional_revenue DESC;

-- Customer Lifetime Value Analysis --

SELECT
c.customer_id,
CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
SUM(oi.quantity * oi.unit_price) AS total_spending,
COUNT(DISTINCT(o.order_id)) AS order_count
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
JOIN orderitems oi ON o.order_id = oi.order_id
WHERE o.current_status != 'Cancelled'
GROUP BY c.customer_id
HAVING order_count > 1
ORDER BY total_spending DESC;

-- Shipping Time Tracker --

DELIMITER //

CREATE FUNCTION DaysToDeliver(ship_id INT)
RETURNS INT
DETERMINISTIC
BEGIN
	DECLARE day_diff INT;
    
    SELECT DATEDIFF(delivered_at, created_at)
    INTO day_diff
    FROM shipments
    WHERE shipment_id = ship_id;
    
    RETURN day_diff;
END //

DELIMITER ;

-- Warehouse Report --

DELIMITER //

CREATE PROCEDURE WarehouseReport()
BEGIN
	SELECT 
    s.order_id,
	w.warehouse_name,
	l.city,
	DaysToDeliver(s.shipment_id) AS days_in_transit
FROM
orders AS o
JOIN shipments AS s ON s.order_id = o.order_id
JOIN warehouses AS w ON s.warehouse_id = w.warehouse_id
JOIN locations AS l ON l.postal_code = w.postal_code
WHERE o.current_status = 'Delivered'
HAVING days_in_transit < 2 OR days_in_transit > 4
ORDER BY days_in_transit DESC;
END //

DELIMITER ;

CALL WarehouseReport();

-- Warehouse Report Improved --

DELIMITER //

CREATE PROCEDURE WarehouseReportNew()
BEGIN
	SELECT
    s.order_id,
    w.warehouse_name,
    l.city,
    DATEDIFF(s.delivered_at, s.created_at) AS delivery_time
    FROM orders AS o
	JOIN shipments AS s ON s.order_id = o.order_id
    JOIN warehouses AS w ON s.warehouse_id = w.warehouse_id
    JOIN locations AS l ON l.postal_code = w.postal_code
	WHERE o.current_status = 'Delivered'
		AND (DATEDIFF(s.delivered_at, s.created_at) < 2
			OR DATEDIFF(s.delivered_at, s.created_at) > 4)
	ORDER BY delivery_time DESC;
END //

DELIMITER ;

CALL WarehouseReportNew();

SELECT
c.customer_id,
oi.order_id,
COUNT(DISTINCT(oi.product_id)) AS product_count
FROM orderitems AS oi
JOIN orders AS o ON oi.order_id = o.order_id
JOIN customers AS c ON o.customer_id = c.customer_id
GROUP BY c.first_name, c.last_name, oi.order_id
HAVING COUNT(oi.product_id) > 1;


WITH temp AS (
SELECT
oi.*,
c.customer_id,
CONCAT(c.first_name, ' ', c.last_name) AS customer_name
FROM orderitems AS oi
JOIN orders AS o ON oi.order_id = o.order_id
JOIN customers AS c ON o.customer_id = c.customer_id)
SELECT *
FROM temp
WHERE customer_id = 1 AND order_id = 26;