CREATE TABLE Customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    contact VARCHAR(50)
);

CREATE TABLE Menu_Items (
    item_id INT AUTO_INCREMENT PRIMARY KEY,
    item_name VARCHAR(100) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    stock INT NOT NULL
);

CREATE TABLE Orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    order_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    status ENUM('Pending','Completed','Cancelled') DEFAULT 'Pending',
    FOREIGN KEY(customer_id) REFERENCES Customers(customer_id)
);

CREATE TABLE Order_Details (
    order_detail_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    item_id INT NOT NULL,
    quantity INT NOT NULL,
    FOREIGN KEY(order_id) REFERENCES Orders(order_id),
    FOREIGN KEY(item_id) REFERENCES Menu_Items(item_id)
);

-- =========================
-- Sample Data
-- =========================

INSERT INTO Customers(customer_name, contact) VALUES 
('Ali','0555123456'),
('Sara','0555987654');

INSERT INTO Menu_Items(item_name, price, stock) VALUES
('Classic Burger',20,10),
('Cheesy Garlic Pizza',35,7),
('Creamy Pasta',25,8),
('Chicken Shawarma',15,12),
('Crispy Fries',10,20),
('Fresh Juices',8,25);

-- =========================
-- Triggers
-- =========================

-- Before inserting order details: check stock
DELIMITER $$
CREATE TRIGGER trg_CheckStock BEFORE INSERT ON Order_Details
FOR EACH ROW
BEGIN
    DECLARE current_stock INT;
    SELECT stock INTO current_stock FROM Menu_Items WHERE item_id = NEW.item_id;
    IF current_stock < NEW.quantity THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Not enough stock!';
    END IF;
END$$
DELIMITER ;

-- After inserting order details: reduce stock
DELIMITER $$
CREATE TRIGGER trg_ReduceStock AFTER INSERT ON Order_Details
FOR EACH ROW
BEGIN
    UPDATE Menu_Items SET stock = stock - NEW.quantity WHERE item_id = NEW.item_id;
END$$
DELIMITER ;

-- After updating order status to Cancelled: restock
DELIMITER $$
CREATE TRIGGER trg_RestockOnCancel AFTER UPDATE ON Orders
FOR EACH ROW
BEGIN
    IF NEW.status = 'Cancelled' AND OLD.status != 'Cancelled' THEN
        UPDATE Menu_Items m
        JOIN Order_Details od ON m.item_id = od.item_id
        SET m.stock = m.stock + od.quantity
        WHERE od.order_id = OLD.order_id;
    END IF;
END$$
DELIMITER ;

-- =========================
-- Views
-- =========================

CREATE VIEW vw_PopularItems AS
SELECT m.item_id, m.item_name, IFNULL(SUM(od.quantity),0) AS total_ordered
FROM Menu_Items m
LEFT JOIN Order_Details od ON m.item_id = od.item_id
GROUP BY m.item_id
ORDER BY total_ordered DESC;

CREATE VIEW vw_PendingOrders AS
SELECT o.order_id, c.customer_name, o.order_date, o.status
FROM Orders o
JOIN Customers c ON o.customer_id = c.customer_id
WHERE o.status = 'Pending';

CREATE VIEW vw_CustomerHistory AS
SELECT o.order_id, c.customer_name, o.order_date, o.status,
       m.item_name, od.quantity, (m.price*od.quantity) AS total_price
FROM Orders o
JOIN Customers c ON o.customer_id = c.customer_id
JOIN Order_Details od ON o.order_id = od.order_id
JOIN Menu_Items m ON od.item_id = m.item_id
ORDER BY c.customer_id, o.order_date;

-- =========================
-- Stored Procedures
-- =========================

-- Place a new order
DELIMITER $$
CREATE PROCEDURE PlaceOrder(
    IN p_customer_id INT
)
BEGIN
    INSERT INTO Orders(customer_id) VALUES (p_customer_id);
END$$
DELIMITER ;

-- Add items to order
DELIMITER $$
CREATE PROCEDURE AddItemToOrder(
    IN p_order_id INT,
    IN p_item_id INT,
    IN p_quantity INT
)
BEGIN
    INSERT INTO Order_Details(order_id, item_id, quantity)
    VALUES (p_order_id, p_item_id, p_quantity);
END$$
DELIMITER ;

-- Update order status
DELIMITER $$
CREATE PROCEDURE UpdateOrderStatus(
    IN p_order_id INT,
    IN p_status ENUM('Pending','Completed','Cancelled')
)
BEGIN
    UPDATE Orders SET status = p_status WHERE order_id = p_order_id;
END$$
DELIMITER ;

