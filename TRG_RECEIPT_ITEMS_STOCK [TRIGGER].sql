/* =========================================================
   CAR SERVICE CENTER
   BUSINESS TRIGGERS
   RUN ALL WITH F5
   ========================================================= */


/* =========================================================
   1) INCREASE STOCK AFTER RECEIVING PARTS
   ========================================================= */

CREATE OR REPLACE TRIGGER TRG_RECEIPT_ITEMS_STOCK
AFTER INSERT ON RECEIPT_ITEMS
FOR EACH ROW
BEGIN

    UPDATE PARTS
    SET QUANTITY_ON_HAND =
        QUANTITY_ON_HAND + :NEW.QUANTITY
    WHERE PART_ID = :NEW.PART_ID;

END;
/


/* =========================================================
   2) UPDATE STOCK WHEN RECEIPT ITEM IS UPDATED
   ========================================================= */

CREATE OR REPLACE TRIGGER TRG_RECEIPT_ITEMS_STOCK_UPD
AFTER UPDATE ON RECEIPT_ITEMS
FOR EACH ROW
BEGIN

    /* Restore old quantity */
    UPDATE PARTS
    SET QUANTITY_ON_HAND =
        QUANTITY_ON_HAND - :OLD.QUANTITY
    WHERE PART_ID = :OLD.PART_ID;

    /* Add new quantity */
    UPDATE PARTS
    SET QUANTITY_ON_HAND =
        QUANTITY_ON_HAND + :NEW.QUANTITY
    WHERE PART_ID = :NEW.PART_ID;

END;
/


/* =========================================================
   3) RETURN STOCK WHEN RECEIPT ITEM IS DELETED
   ========================================================= */

CREATE OR REPLACE TRIGGER TRG_RECEIPT_ITEMS_STOCK_DEL
AFTER DELETE ON RECEIPT_ITEMS
FOR EACH ROW
BEGIN

    UPDATE PARTS
    SET QUANTITY_ON_HAND =
        QUANTITY_ON_HAND - :OLD.QUANTITY
    WHERE PART_ID = :OLD.PART_ID;

END;
/


/* =========================================================
   4) CHECK STOCK BEFORE ISSUING PARTS
   INSERT + UPDATE
   ========================================================= */

CREATE OR REPLACE TRIGGER TRG_PARTS_ISSUED_CHECK
BEFORE INSERT OR UPDATE ON PARTS_ISSUED
FOR EACH ROW
DECLARE
    V_STOCK PARTS.QUANTITY_ON_HAND%TYPE;
BEGIN

    SELECT QUANTITY_ON_HAND
    INTO V_STOCK
    FROM PARTS
    WHERE PART_ID = :NEW.PART_ID
    FOR UPDATE;


    /* INSERT */
    IF INSERTING THEN

        IF :NEW.QUANTITY_ISSUED > V_STOCK THEN

            RAISE_APPLICATION_ERROR(
                -20001,
                'Insufficient stock. Available quantity = '
                || V_STOCK
            );

        END IF;

    END IF;


    /* UPDATE */
    IF UPDATING THEN

        /* Same part */
        IF :OLD.PART_ID = :NEW.PART_ID THEN

            IF :NEW.QUANTITY_ISSUED >
               V_STOCK + :OLD.QUANTITY_ISSUED THEN

                RAISE_APPLICATION_ERROR(
                    -20001,
                    'Insufficient stock. Available quantity = '
                    || (V_STOCK + :OLD.QUANTITY_ISSUED)
                );

            END IF;

        ELSE

            /* Different part */
            IF :NEW.QUANTITY_ISSUED > V_STOCK THEN

                RAISE_APPLICATION_ERROR(
                    -20001,
                    'Insufficient stock for the new part. Available quantity = '
                    || V_STOCK
                );

            END IF;

        END IF;

    END IF;

END;
/


/* =========================================================
   5) DECREASE STOCK AFTER PART ISSUE
   INSERT
   ========================================================= */

CREATE OR REPLACE TRIGGER TRG_PARTS_ISSUED_STOCK
AFTER INSERT ON PARTS_ISSUED
FOR EACH ROW
BEGIN

    UPDATE PARTS
    SET QUANTITY_ON_HAND =
        QUANTITY_ON_HAND - :NEW.QUANTITY_ISSUED
    WHERE PART_ID = :NEW.PART_ID;

END;
/


/* =========================================================
   6) UPDATE STOCK WHEN PART ISSUE IS UPDATED
   ========================================================= */

CREATE OR REPLACE TRIGGER TRG_PARTS_ISSUED_STOCK_UPD
AFTER UPDATE ON PARTS_ISSUED
FOR EACH ROW
BEGIN

    /* Return old quantity */
    UPDATE PARTS
    SET QUANTITY_ON_HAND =
        QUANTITY_ON_HAND + :OLD.QUANTITY_ISSUED
    WHERE PART_ID = :OLD.PART_ID;

    /* Remove new quantity */
    UPDATE PARTS
    SET QUANTITY_ON_HAND =
        QUANTITY_ON_HAND - :NEW.QUANTITY_ISSUED
    WHERE PART_ID = :NEW.PART_ID;

END;
/


/* =========================================================
   7) RETURN STOCK WHEN PART ISSUE IS DELETED
   ========================================================= */

CREATE OR REPLACE TRIGGER TRG_PARTS_ISSUED_STOCK_DEL
AFTER DELETE ON PARTS_ISSUED
FOR EACH ROW
BEGIN

    UPDATE PARTS
    SET QUANTITY_ON_HAND =
        QUANTITY_ON_HAND + :OLD.QUANTITY_ISSUED
    WHERE PART_ID = :OLD.PART_ID;

END;
/


/* =========================================================
   8) ODOMETER VALIDATION
   ========================================================= */

CREATE OR REPLACE TRIGGER TRG_JOB_CARD_ODOMETER
BEFORE INSERT ON JOB_CARDS
FOR EACH ROW
DECLARE
    V_CURRENT_ODOMETER VEHICLES.ODOMETER%TYPE;
BEGIN

    SELECT ODOMETER
    INTO V_CURRENT_ODOMETER
    FROM VEHICLES
    WHERE VEHICLE_ID = :NEW.VEHICLE_ID
    FOR UPDATE;

    IF :NEW.ODOMETER_READING < V_CURRENT_ODOMETER THEN

        RAISE_APPLICATION_ERROR(
            -20002,
            'Odometer cannot be less than current vehicle odometer. Current = '
            || V_CURRENT_ODOMETER
        );

    END IF;

END;
/


/* =========================================================
   9) UPDATE VEHICLE ODOMETER
   ========================================================= */

CREATE OR REPLACE TRIGGER TRG_UPDATE_VEHICLE_ODOMETER
AFTER INSERT ON JOB_CARDS
FOR EACH ROW
BEGIN

    UPDATE VEHICLES
    SET ODOMETER = :NEW.ODOMETER_READING
    WHERE VEHICLE_ID = :NEW.VEHICLE_ID
      AND ODOMETER < :NEW.ODOMETER_READING;

END;
/


/* =========================================================
   10) LOCK DELIVERED / CANCELED JOB CARDS
   ========================================================= */

CREATE OR REPLACE TRIGGER TRG_LOCK_CLOSED_JOB_CARD
BEFORE UPDATE ON JOB_CARDS
FOR EACH ROW
DECLARE
    V_OLD_STATUS VARCHAR2(50);
BEGIN

    SELECT STATUS_NAME
    INTO V_OLD_STATUS
    FROM JOB_STATUS
    WHERE STATUS_ID = :OLD.STATUS_ID;

    IF V_OLD_STATUS IN ('DELIVERED', 'CANCELED') THEN

        RAISE_APPLICATION_ERROR(
            -20003,
            'This Job Card is closed and cannot be modified.'
        );

    END IF;

END;
/


/* =========================================================
   11) PREVENT DELETE JOB CARD
   ========================================================= */

CREATE OR REPLACE TRIGGER TRG_NO_DELETE_JOB_CARD
BEFORE DELETE ON JOB_CARDS
FOR EACH ROW
BEGIN

    RAISE_APPLICATION_ERROR(
        -20004,
        'Job Cards cannot be deleted.'
    );

END;
/


/* =========================================================
   12) JOB CARD STATUS WORKFLOW
   ========================================================= */

CREATE OR REPLACE TRIGGER TRG_JOB_CARD_STATUS
BEFORE UPDATE OF STATUS_ID ON JOB_CARDS
FOR EACH ROW
DECLARE

    V_OLD_STATUS VARCHAR2(50);
    V_NEW_STATUS VARCHAR2(50);

BEGIN

    SELECT STATUS_NAME
    INTO V_OLD_STATUS
    FROM JOB_STATUS
    WHERE STATUS_ID = :OLD.STATUS_ID;


    SELECT STATUS_NAME
    INTO V_NEW_STATUS
    FROM JOB_STATUS
    WHERE STATUS_ID = :NEW.STATUS_ID;


    /* No status change */
    IF V_OLD_STATUS = V_NEW_STATUS THEN
        RETURN;
    END IF;


    /* =============================================
       NEW
       ============================================= */

    IF V_OLD_STATUS = 'NEW' THEN

        IF V_NEW_STATUS NOT IN
           ('INSPECTING', 'CANCELED') THEN

            RAISE_APPLICATION_ERROR(
                -20005,
                'Invalid status transition: NEW -> '
                || V_NEW_STATUS
            );

        END IF;

    END IF;


    /* =============================================
       INSPECTING
       ============================================= */

    IF V_OLD_STATUS = 'INSPECTING' THEN

        IF V_NEW_STATUS NOT IN
           ('WAITING_APPROVAL', 'CANCELED') THEN

            RAISE_APPLICATION_ERROR(
                -20006,
                'Invalid status transition: INSPECTING -> '
                || V_NEW_STATUS
            );

        END IF;

    END IF;


    /* =============================================
       WAITING_APPROVAL
       ============================================= */

    IF V_OLD_STATUS = 'WAITING_APPROVAL' THEN

        IF V_NEW_STATUS NOT IN
           ('IN_PROGRESS', 'CANCELED') THEN

            RAISE_APPLICATION_ERROR(
                -20007,
                'Invalid status transition: WAITING_APPROVAL -> '
                || V_NEW_STATUS
            );

        END IF;

    END IF;


    /* =============================================
       IN_PROGRESS
       ============================================= */

    IF V_OLD_STATUS = 'IN_PROGRESS' THEN

        IF V_NEW_STATUS NOT IN
           ('WASHING', 'READY') THEN

            RAISE_APPLICATION_ERROR(
                -20008,
                'Invalid status transition: IN_PROGRESS -> '
                || V_NEW_STATUS
            );

        END IF;

    END IF;


    /* =============================================
       WASHING
       ============================================= */

    IF V_OLD_STATUS = 'WASHING' THEN

        IF V_NEW_STATUS <> 'READY' THEN

            RAISE_APPLICATION_ERROR(
                -20009,
                'Invalid status transition: WASHING -> '
                || V_NEW_STATUS
            );

        END IF;

    END IF;


    /* =============================================
       READY
       ============================================= */

    IF V_OLD_STATUS = 'READY' THEN

        IF V_NEW_STATUS <> 'DELIVERED' THEN

            RAISE_APPLICATION_ERROR(
                -20010,
                'Invalid status transition: READY -> '
                || V_NEW_STATUS
            );

        END IF;

    END IF;


    /* =============================================
       DELIVERED
       ============================================= */

    IF V_OLD_STATUS = 'DELIVERED' THEN

        RAISE_APPLICATION_ERROR(
            -20011,
            'Delivered Job Card cannot change status.'
        );

    END IF;


    /* =============================================
       CANCELED
       ============================================= */

    IF V_OLD_STATUS = 'CANCELED' THEN

        RAISE_APPLICATION_ERROR(
            -20012,
            'Canceled Job Card cannot change status.'
        );

    END IF;

END;
/


/* =========================================================
   CHECK ALL BUSINESS TRIGGERS
   ========================================================= */

SELECT TRIGGER_NAME, STATUS
FROM USER_TRIGGERS
WHERE TRIGGER_NAME IN
(
    'TRG_RECEIPT_ITEMS_STOCK',
    'TRG_RECEIPT_ITEMS_STOCK_UPD',
    'TRG_RECEIPT_ITEMS_STOCK_DEL',
    'TRG_PARTS_ISSUED_CHECK',
    'TRG_PARTS_ISSUED_STOCK',
    'TRG_PARTS_ISSUED_STOCK_UPD',
    'TRG_PARTS_ISSUED_STOCK_DEL',
    'TRG_JOB_CARD_ODOMETER',
    'TRG_UPDATE_VEHICLE_ODOMETER',
    'TRG_LOCK_CLOSED_JOB_CARD',
    'TRG_NO_DELETE_JOB_CARD',
    'TRG_JOB_CARD_STATUS'
)
ORDER BY TRIGGER_NAME;