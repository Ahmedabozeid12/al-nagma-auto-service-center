/* =========================================================
   1) ROLES
   ========================================================= */

CREATE TABLE ROLES (
    ROLE_ID     NUMBER PRIMARY KEY,
    ROLE_NAME   VARCHAR2(50) NOT NULL UNIQUE
);


/* =========================================================
   2) USERS
   ========================================================= */

CREATE TABLE USERS (
    USER_ID        NUMBER PRIMARY KEY,
    ROLE_ID        NUMBER NOT NULL,
    USERNAME       VARCHAR2(50) NOT NULL UNIQUE,
    PASSWORD_USER  VARCHAR2(255) NOT NULL,
    FULL_NAME      VARCHAR2(100) NOT NULL,

    CONSTRAINT FK_USERS_ROLE
        FOREIGN KEY (ROLE_ID)
        REFERENCES ROLES(ROLE_ID)
);


/* =========================================================
   3) CUSTOMERS
   ========================================================= */

CREATE TABLE CUSTOMERS (
    CUSTOMER_ID     NUMBER PRIMARY KEY,
    FULL_NAME       VARCHAR2(100) NOT NULL,
    PHONE           VARCHAR2(11) NOT NULL UNIQUE,
    NATIONAL_ID     VARCHAR2(14) UNIQUE,
    ADDRESS         VARCHAR2(500),
    CUSTOMER_TYPE   VARCHAR2(20) DEFAULT 'INDIVIDUAL' NOT NULL,
    GENDER          VARCHAR2(10),

    CONSTRAINT CHK_CUSTOMER_PHONE
        CHECK (
            LENGTH(PHONE) = 11
            AND SUBSTR(PHONE,1,2) = '01'
            AND REGEXP_LIKE(PHONE, '^[0-9]+$')
        ),

    CONSTRAINT CHK_CUSTOMER_NATIONAL_ID
        CHECK (
            NATIONAL_ID IS NULL
            OR (
                LENGTH(NATIONAL_ID) = 14
                AND REGEXP_LIKE(NATIONAL_ID, '^[0-9]+$')
            )
        ),

    CONSTRAINT CHK_CUSTOMER_TYPE
        CHECK (CUSTOMER_TYPE IN ('INDIVIDUAL','COMPANY')),

    CONSTRAINT CHK_CUSTOMER_GENDER
        CHECK (GENDER IS NULL OR GENDER IN ('MALE','FEMALE'))
);


/* =========================================================
   4) VEHICLES
   ========================================================= */

CREATE TABLE VEHICLES (
    VEHICLE_ID       NUMBER PRIMARY KEY,
    CUSTOMER_ID      NUMBER NOT NULL,
    PLATE_NUMBER     VARCHAR2(30) NOT NULL UNIQUE,
    MAKE             VARCHAR2(50) NOT NULL,
    MODEL            VARCHAR2(50),
    YEAR             NUMBER(4),
    COLOR            VARCHAR2(30),
    VIN              VARCHAR2(50) UNIQUE,
    ODOMETER         NUMBER DEFAULT 0 NOT NULL,
    VEHICLE_SIZE     VARCHAR2(20),

    CONSTRAINT FK_VEHICLES_CUSTOMER
        FOREIGN KEY (CUSTOMER_ID)
        REFERENCES CUSTOMERS(CUSTOMER_ID),

    CONSTRAINT CHK_VEHICLE_ODOMETER
        CHECK (ODOMETER >= 0),

    CONSTRAINT CHK_VEHICLE_SIZE
        CHECK (
            VEHICLE_SIZE IS NULL
            OR VEHICLE_SIZE IN ('SMALL','LARGE','JEEP')
        )
);


/* =========================================================
   5) JOB STATUS
   ========================================================= */

CREATE TABLE JOB_STATUS (
    STATUS_ID      NUMBER PRIMARY KEY,
    STATUS_NAME    VARCHAR2(50) NOT NULL UNIQUE,
    STATUS_ORDER   NUMBER NOT NULL UNIQUE
);


/* =========================================================
   6) JOB CARDS
   ========================================================= */

CREATE TABLE JOB_CARDS (
    JOB_CARD_ID          NUMBER PRIMARY KEY,
    VEHICLE_ID           NUMBER NOT NULL,
    STATUS_ID            NUMBER NOT NULL,
    CREATED_BY_USER_ID   NUMBER NOT NULL,

    OPEN_DATE            DATE DEFAULT SYSDATE NOT NULL,
    CLOSE_DATE           DATE,

    CUSTOMER_COMPLAINT   VARCHAR2(1000),
    ODOMETER_READING     NUMBER NOT NULL,
    EXPECTED_DELIVERY    DATE,
    WASH_REQUESTED       CHAR(1) DEFAULT 'N' NOT NULL,

    CONSTRAINT FK_JOB_CARD_VEHICLE
        FOREIGN KEY (VEHICLE_ID)
        REFERENCES VEHICLES(VEHICLE_ID),

    CONSTRAINT FK_JOB_CARD_STATUS
        FOREIGN KEY (STATUS_ID)
        REFERENCES JOB_STATUS(STATUS_ID),

    CONSTRAINT FK_JOB_CARD_USER
        FOREIGN KEY (CREATED_BY_USER_ID)
        REFERENCES USERS(USER_ID),

    CONSTRAINT CHK_JOB_ODOMETER
        CHECK (ODOMETER_READING >= 0),

    CONSTRAINT CHK_WASH_REQUESTED
        CHECK (WASH_REQUESTED IN ('Y','N'))
);


/* =========================================================
   7) TECHNICIANS
   ========================================================= */

CREATE TABLE TECHNICIANS (
    TECHNICIAN_ID   NUMBER PRIMARY KEY,
    FULL_NAME       VARCHAR2(100) NOT NULL,
    SPECIALTY       VARCHAR2(100),
    PHONE           VARCHAR2(20),
    IS_ACTIVE       CHAR(1) DEFAULT 'Y' NOT NULL,

    CONSTRAINT CHK_TECH_ACTIVE
        CHECK (IS_ACTIVE IN ('Y','N'))
);


/* =========================================================
   8) SERVICES
   ========================================================= */

CREATE TABLE SERVICES (
    SERVICE_ID      NUMBER PRIMARY KEY,
    SERVICE_NAME    VARCHAR2(100) NOT NULL UNIQUE,
    DESCRIPTION     VARCHAR2(500),
    UNIT_PRICE      NUMBER(12,2) NOT NULL,
    IS_ACTIVE       CHAR(1) DEFAULT 'Y' NOT NULL,

    CONSTRAINT CHK_SERVICE_PRICE
        CHECK (UNIT_PRICE >= 0),

    CONSTRAINT CHK_SERVICE_ACTIVE
        CHECK (IS_ACTIVE IN ('Y','N'))
);


/* =========================================================
   9) JOB CARD SERVICES
   ========================================================= */

CREATE TABLE JOB_CARD_SERVICES (
    JOB_CARD_SERVICE_ID   NUMBER PRIMARY KEY,
    JOB_CARD_ID           NUMBER NOT NULL,
    SERVICE_ID            NUMBER NOT NULL,
    TECHNICIAN_ID         NUMBER,
    QUANTITY               NUMBER DEFAULT 1 NOT NULL,
    UNIT_PRICE             NUMBER(12,2) NOT NULL,
    LINE_STATUS            VARCHAR2(20) DEFAULT 'COMPLETED' NOT NULL,

    CONSTRAINT FK_JCS_JOB_CARD
        FOREIGN KEY (JOB_CARD_ID)
        REFERENCES JOB_CARDS(JOB_CARD_ID),

    CONSTRAINT FK_JCS_SERVICE
        FOREIGN KEY (SERVICE_ID)
        REFERENCES SERVICES(SERVICE_ID),

    CONSTRAINT FK_JCS_TECHNICIAN
        FOREIGN KEY (TECHNICIAN_ID)
        REFERENCES TECHNICIANS(TECHNICIAN_ID),

    CONSTRAINT CHK_JCS_QTY
        CHECK (QUANTITY > 0),

    CONSTRAINT CHK_JCS_PRICE
        CHECK (UNIT_PRICE >= 0),

    CONSTRAINT CHK_JCS_STATUS
        CHECK (
            LINE_STATUS IN
            ('CANCELED','SUSPEND','COMPLETED')
        )
);


/* =========================================================
   10) PARTS
   ========================================================= */

CREATE TABLE PARTS (
    PART_ID           NUMBER PRIMARY KEY,
    PART_CODE         VARCHAR2(50) NOT NULL UNIQUE,
    PART_NAME         VARCHAR2(100) NOT NULL,
    CATEGORY          VARCHAR2(100),
    UNIT              VARCHAR2(30) DEFAULT 'PIECE',
    PURCHASE_PRICE    NUMBER(12,2) DEFAULT 0 NOT NULL,
    SELLING_PRICE     NUMBER(12,2) DEFAULT 0 NOT NULL,
    QUANTITY_ON_HAND  NUMBER(12,2) DEFAULT 0 NOT NULL,
    REORDER_LEVEL     NUMBER(12,2) DEFAULT 0 NOT NULL,

    CONSTRAINT CHK_PART_PURCHASE
        CHECK (PURCHASE_PRICE >= 0),

    CONSTRAINT CHK_PART_SELLING
        CHECK (SELLING_PRICE >= 0),

    CONSTRAINT CHK_PART_QTY
        CHECK (QUANTITY_ON_HAND >= 0),

    CONSTRAINT CHK_PART_REORDER
        CHECK (REORDER_LEVEL >= 0)
);


/* =========================================================
   11) SUPPLIERS
   ========================================================= */

CREATE TABLE SUPPLIERS (
    SUPPLIER_ID     NUMBER PRIMARY KEY,
    SUPPLIER_NAME   VARCHAR2(150) NOT NULL,
    PHONE           VARCHAR2(20),
    ADDRESS         VARCHAR2(500),
    TAX_NUMBER      VARCHAR2(50)
);


/* =========================================================
   12) RECEIPTS - GOODS RECEIPT
   ========================================================= */

CREATE TABLE RECEIPTS (
    RECEIPT_ID        NUMBER PRIMARY KEY,
    SUPPLIER_ID       NUMBER NOT NULL,
    RECEIVED_BY_USER  NUMBER NOT NULL,
    RECEIPT_DATE      DATE DEFAULT SYSDATE NOT NULL,
    NOTES             VARCHAR2(500),

    CONSTRAINT FK_RECEIPTS_SUPPLIER
        FOREIGN KEY (SUPPLIER_ID)
        REFERENCES SUPPLIERS(SUPPLIER_ID),

    CONSTRAINT FK_RECEIPTS_USER
        FOREIGN KEY (RECEIVED_BY_USER)
        REFERENCES USERS(USER_ID)
);


/* =========================================================
   13) RECEIPT ITEMS
   ========================================================= */

CREATE TABLE RECEIPT_ITEMS (
    RECEIPT_ITEM_ID   NUMBER PRIMARY KEY,
    RECEIPT_ID        NUMBER NOT NULL,
    PART_ID           NUMBER NOT NULL,
    QUANTITY          NUMBER(12,2) NOT NULL,
    UNIT_COST         NUMBER(12,2) NOT NULL,

    CONSTRAINT FK_RECEIPT_ITEMS_RECEIPT
        FOREIGN KEY (RECEIPT_ID)
        REFERENCES RECEIPTS(RECEIPT_ID),

    CONSTRAINT FK_RECEIPT_ITEMS_PART
        FOREIGN KEY (PART_ID)
        REFERENCES PARTS(PART_ID),

    CONSTRAINT CHK_RECEIPT_QTY
        CHECK (QUANTITY > 0),

    CONSTRAINT CHK_RECEIPT_COST
        CHECK (UNIT_COST >= 0)
);


/* =========================================================
   14) PARTS ISSUED
   ========================================================= */

CREATE TABLE PARTS_ISSUED (
    PART_ISSUED_ID      NUMBER PRIMARY KEY,
    JOB_CARD_ID         NUMBER NOT NULL,
    PART_ID             NUMBER NOT NULL,
    ISSUED_BY_USER_ID   NUMBER NOT NULL,
    QUANTITY_ISSUED     NUMBER(12,2) NOT NULL,
    UNIT_COST            NUMBER(12,2) NOT NULL,
    ISSUE_DATE           DATE DEFAULT SYSDATE NOT NULL,

    CONSTRAINT FK_PI_JOB_CARD
        FOREIGN KEY (JOB_CARD_ID)
        REFERENCES JOB_CARDS(JOB_CARD_ID),

    CONSTRAINT FK_PI_PART
        FOREIGN KEY (PART_ID)
        REFERENCES PARTS(PART_ID),

    CONSTRAINT FK_PI_USER
        FOREIGN KEY (ISSUED_BY_USER_ID)
        REFERENCES USERS(USER_ID),

    CONSTRAINT CHK_PI_QTY
        CHECK (QUANTITY_ISSUED > 0),

    CONSTRAINT CHK_PI_COST
        CHECK (UNIT_COST >= 0)
);


/* =========================================================
   15) PAYMENT METHODS
   ========================================================= */

CREATE TABLE PAYMENT_METHODS (
    PAYMENT_METHOD_ID   NUMBER PRIMARY KEY,
    METHOD_NAME         VARCHAR2(50) NOT NULL UNIQUE
);


/* =========================================================
   16) INVOICES
   ========================================================= */

CREATE TABLE INVOICES (
    INVOICE_ID       NUMBER PRIMARY KEY,
    JOB_CARD_ID      NUMBER NOT NULL UNIQUE,
    INVOICE_DATE     DATE DEFAULT SYSDATE NOT NULL,

    SUBTOTAL         NUMBER(12,2) DEFAULT 0 NOT NULL,
    DISCOUNT_AMOUNT  NUMBER(12,2) DEFAULT 0 NOT NULL,
    VAT_AMOUNT       NUMBER(12,2) DEFAULT 0 NOT NULL,
    NET_TOTAL        NUMBER(12,2) DEFAULT 0 NOT NULL,

    CREATED_BY_USER_ID NUMBER NOT NULL,

    CONSTRAINT FK_INVOICE_JOB_CARD
        FOREIGN KEY (JOB_CARD_ID)
        REFERENCES JOB_CARDS(JOB_CARD_ID),

    CONSTRAINT FK_INVOICE_USER
        FOREIGN KEY (CREATED_BY_USER_ID)
        REFERENCES USERS(USER_ID),

    CONSTRAINT CHK_INVOICE_SUBTOTAL
        CHECK (SUBTOTAL >= 0),

    CONSTRAINT CHK_INVOICE_DISCOUNT
        CHECK (DISCOUNT_AMOUNT >= 0),

    CONSTRAINT CHK_INVOICE_VAT
        CHECK (VAT_AMOUNT >= 0),

    CONSTRAINT CHK_INVOICE_NET
        CHECK (NET_TOTAL >= 0)
);


/* =========================================================
   17) PAYMENTS
   ========================================================= */

CREATE TABLE PAYMENTS (
    PAYMENT_ID          NUMBER PRIMARY KEY,
    INVOICE_ID          NUMBER NOT NULL,
    PAYMENT_METHOD_ID   NUMBER NOT NULL,
    AMOUNT              NUMBER(12,2) NOT NULL,
    PAYMENT_DATE        DATE DEFAULT SYSDATE NOT NULL,
    RECEIVED_BY_USER_ID NUMBER NOT NULL,
    NOTES               VARCHAR2(500),

    CONSTRAINT FK_PAYMENTS_INVOICE
        FOREIGN KEY (INVOICE_ID)
        REFERENCES INVOICES(INVOICE_ID),

    CONSTRAINT FK_PAYMENTS_METHOD
        FOREIGN KEY (PAYMENT_METHOD_ID)
        REFERENCES PAYMENT_METHODS(PAYMENT_METHOD_ID),

    CONSTRAINT FK_PAYMENTS_USER
        FOREIGN KEY (RECEIVED_BY_USER_ID)
        REFERENCES USERS(USER_ID),

    CONSTRAINT CHK_PAYMENT_AMOUNT
        CHECK (AMOUNT > 0)
);


/* =========================================================
   18) CAR WASH
   ========================================================= */

CREATE TABLE CAR_WASH (
    CAR_WASH_ID          NUMBER PRIMARY KEY,
    JOB_CARD_ID          NUMBER UNIQUE,
    PERFORMED_BY_USER_ID NUMBER NOT NULL,

    WASH_TYPE            VARCHAR2(20) NOT NULL,
    WASH_DATE            DATE DEFAULT SYSDATE NOT NULL,
    PRICE                NUMBER(12,2) DEFAULT 0 NOT NULL,
    NOTES                VARCHAR2(500),

    CONSTRAINT FK_WASH_JOB_CARD
        FOREIGN KEY (JOB_CARD_ID)
        REFERENCES JOB_CARDS(JOB_CARD_ID),

    CONSTRAINT FK_WASH_USER
        FOREIGN KEY (PERFORMED_BY_USER_ID)
        REFERENCES USERS(USER_ID),

    CONSTRAINT CHK_WASH_TYPE
        CHECK (
            WASH_TYPE IN ('EXTERIOR','INTERIOR','FULL')
        ),

    CONSTRAINT CHK_WASH_PRICE
        CHECK (PRICE >= 0)
);


/* =========================================================
   19) WASH PRICES
   ========================================================= */

CREATE TABLE WASH_PRICES (
    WASH_PRICE_ID   NUMBER PRIMARY KEY,
    WASH_TYPE       VARCHAR2(20) NOT NULL,
    VEHICLE_SIZE    VARCHAR2(20) NOT NULL,
    PRICE           NUMBER(12,2) NOT NULL,

    CONSTRAINT UQ_WASH_PRICE
        UNIQUE (WASH_TYPE, VEHICLE_SIZE),

    CONSTRAINT CHK_WP_TYPE
        CHECK (
            WASH_TYPE IN ('EXTERIOR','INTERIOR','FULL')
        ),

    CONSTRAINT CHK_WP_SIZE
        CHECK (
            VEHICLE_SIZE IN ('SMALL','LARGE','JEEP')
        ),

    CONSTRAINT CHK_WP_PRICE
        CHECK (PRICE >= 0)
);


/* =========================================================
   SEQUENCES
   ========================================================= */

/* Roles */
CREATE SEQUENCE ROLE_ID_SEQ
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;


/* Users */
CREATE SEQUENCE USER_ID_SEQ
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;


/* Customers */
CREATE SEQUENCE CUSTOMER_ID_SEQ
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;


/* Vehicles */
CREATE SEQUENCE VEHICLE_ID_SEQ
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;


/* Job Status */
CREATE SEQUENCE JOB_STATUS_ID_SEQ
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;


/* Job Cards */
CREATE SEQUENCE JOB_CARD_ID_SEQ
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;


/* Technicians */
CREATE SEQUENCE TECHNICIAN_ID_SEQ
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;


/* Services */
CREATE SEQUENCE SERVICE_ID_SEQ
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;


/* Job Card Services */
CREATE SEQUENCE JOB_CARD_SERVICE_ID_SEQ
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;


/* Parts */
CREATE SEQUENCE PART_ID_SEQ
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;


/* Suppliers */
CREATE SEQUENCE SUPPLIER_ID_SEQ
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;


/* Receipts */
CREATE SEQUENCE RECEIPT_ID_SEQ
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;


/* Receipt Items */
CREATE SEQUENCE RECEIPT_ITEM_ID_SEQ
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;


/* Parts Issued */
CREATE SEQUENCE PART_ISSUED_ID_SEQ
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;


/* Payment Methods */
CREATE SEQUENCE PAYMENT_METHOD_ID_SEQ
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;


/* Invoices */
CREATE SEQUENCE INVOICE_ID_SEQ
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;


/* Payments */
CREATE SEQUENCE PAYMENT_ID_SEQ
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;


/* Car Wash */
CREATE SEQUENCE CAR_WASH_ID_SEQ
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;


/* Wash Prices */
CREATE SEQUENCE WASH_PRICE_ID_SEQ
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;


CREATE TABLE INVOICE_ITEMS (
    INVOICE_ITEM_ID    NUMBER PRIMARY KEY,
    INVOICE_ID         NUMBER NOT NULL,
    ITEM_TYPE          VARCHAR2(20) NOT NULL,
    DESCRIPTION        VARCHAR2(200) NOT NULL,
    QUANTITY           NUMBER(12,2) NOT NULL,
    UNIT_PRICE         NUMBER(12,2) NOT NULL,
    LINE_TOTAL         NUMBER(12,2) NOT NULL,

    CONSTRAINT FK_INVOICE_ITEMS_INVOICE
        FOREIGN KEY (INVOICE_ID)
        REFERENCES INVOICES(INVOICE_ID),

    CONSTRAINT CHK_INVOICE_ITEM_TYPE
        CHECK (ITEM_TYPE IN ('SERVICE','PART','WASH')),

    CONSTRAINT CHK_INVOICE_ITEM_QTY
        CHECK (QUANTITY > 0),

    CONSTRAINT CHK_INVOICE_ITEM_PRICE
        CHECK (UNIT_PRICE >= 0),

    CONSTRAINT CHK_INVOICE_ITEM_TOTAL
        CHECK (LINE_TOTAL >= 0)
);



CREATE SEQUENCE INVOICE_ITEM_ID_SEQ
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;


ALTER TABLE PARTS_ISSUED
ADD UNIT_PRICE NUMBER(12,2);

ALTER TABLE JOB_CARDS
ADD CONSTRAINT CHK_EXPECTED_DELIVERY
CHECK (
    EXPECTED_DELIVERY IS NULL
    OR EXPECTED_DELIVERY >= OPEN_DATE
);