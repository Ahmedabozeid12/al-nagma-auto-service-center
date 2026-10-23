CREATE OR REPLACE PACKAGE PKG_INVOICE AS

    PROCEDURE CREATE_INVOICE(
        P_JOB_CARD_ID        IN INVOICES.JOB_CARD_ID%TYPE,
        P_CREATED_BY_USER_ID IN INVOICES.CREATED_BY_USER_ID%TYPE,
        P_DISCOUNT_AMOUNT    IN NUMBER DEFAULT 0,
        P_INVOICE_ID         OUT INVOICES.INVOICE_ID%TYPE
    );

    PROCEDURE RECALCULATE_INVOICE(
        P_INVOICE_ID      IN INVOICES.INVOICE_ID%TYPE,
        P_DISCOUNT_AMOUNT IN NUMBER
    );

    PROCEDURE GET_INVOICE(
        P_INVOICE_ID IN INVOICES.INVOICE_ID%TYPE,
        P_RESULT     OUT SYS_REFCURSOR
    );

END PKG_INVOICE;

/

CREATE OR REPLACE PACKAGE BODY PKG_INVOICE AS

    PROCEDURE CREATE_INVOICE(
        P_JOB_CARD_ID        IN INVOICES.JOB_CARD_ID%TYPE,
        P_CREATED_BY_USER_ID IN INVOICES.CREATED_BY_USER_ID%TYPE,
        P_DISCOUNT_AMOUNT    IN NUMBER DEFAULT 0,
        P_INVOICE_ID         OUT INVOICES.INVOICE_ID%TYPE
    )
    IS
        V_SERVICE_TOTAL NUMBER := 0;
        V_PART_TOTAL    NUMBER := 0;
        V_WASH_TOTAL    NUMBER := 0;
        V_SUBTOTAL      NUMBER := 0;
        V_DISCOUNT      NUMBER := 0;
        V_VAT           NUMBER := 0;
        V_NET            NUMBER := 0;
        V_COUNT         NUMBER;
        V_ROLE_NAME     ROLES.ROLE_NAME%TYPE;
    BEGIN

        /* Check Job Card */

        SELECT COUNT(*)
        INTO V_COUNT
        FROM JOB_CARDS
        WHERE JOB_CARD_ID = P_JOB_CARD_ID;

        IF V_COUNT = 0 THEN
            RAISE_APPLICATION_ERROR(
                -20501,
                'Job Card not found.'
            );
        END IF;


        /* Check existing invoice */

        SELECT COUNT(*)
        INTO V_COUNT
        FROM INVOICES
        WHERE JOB_CARD_ID = P_JOB_CARD_ID;

        IF V_COUNT > 0 THEN
            RAISE_APPLICATION_ERROR(
                -20502,
                'Invoice already exists for this Job Card.'
            );
        END IF;


        /* Get user role */

        SELECT R.ROLE_NAME
        INTO V_ROLE_NAME
        FROM USERS U,
             ROLES R
        WHERE U.ROLE_ID = R.ROLE_ID
          AND U.USER_ID = P_CREATED_BY_USER_ID;


        /* Calculate services */

        SELECT NVL(SUM(QUANTITY * UNIT_PRICE),0)
        INTO V_SERVICE_TOTAL
        FROM JOB_CARD_SERVICES
        WHERE JOB_CARD_ID = P_JOB_CARD_ID
          AND LINE_STATUS <> 'CANCELED';


        /* Calculate parts */

        SELECT NVL(SUM(QUANTITY_ISSUED * NVL(UNIT_PRICE,0)),0)
        INTO V_PART_TOTAL
        FROM PARTS_ISSUED
        WHERE JOB_CARD_ID = P_JOB_CARD_ID;


        /* Calculate wash */

        SELECT NVL(SUM(PRICE),0)
        INTO V_WASH_TOTAL
        FROM CAR_WASH
        WHERE JOB_CARD_ID = P_JOB_CARD_ID;


        V_SUBTOTAL :=
            V_SERVICE_TOTAL +
            V_PART_TOTAL +
            V_WASH_TOTAL;


        /* Validate discount */

        IF P_DISCOUNT_AMOUNT < 0 THEN
            RAISE_APPLICATION_ERROR(
                -20503,
                'Discount cannot be negative.'
            );
        END IF;


        IF P_DISCOUNT_AMOUNT > V_SUBTOTAL THEN
            RAISE_APPLICATION_ERROR(
                -20504,
                'Discount cannot exceed subtotal.'
            );
        END IF;


        /* Reception maximum discount = 10% */

        IF V_ROLE_NAME = 'RECEPTION'
           AND P_DISCOUNT_AMOUNT > V_SUBTOTAL * 0.10 THEN

            RAISE_APPLICATION_ERROR(
                -20505,
                'Reception discount cannot exceed 10%.'
            );

        END IF;


        V_DISCOUNT := P_DISCOUNT_AMOUNT;


        /* VAT after discount */

        V_VAT :=
            (V_SUBTOTAL - V_DISCOUNT) * 0.14;


        V_NET :=
            (V_SUBTOTAL - V_DISCOUNT) + V_VAT;


        /* Create invoice */

        INSERT INTO INVOICES
        (
            JOB_CARD_ID,
            SUBTOTAL,
            DISCOUNT_AMOUNT,
            VAT_AMOUNT,
            NET_TOTAL,
            CREATED_BY_USER_ID
        )
        VALUES
        (
            P_JOB_CARD_ID,
            V_SUBTOTAL,
            V_DISCOUNT,
            V_VAT,
            V_NET,
            P_CREATED_BY_USER_ID
        )
        RETURNING INVOICE_ID INTO P_INVOICE_ID;


        /* =========================================
           SERVICE ITEMS
           ========================================= */

        INSERT INTO INVOICE_ITEMS
        (
            INVOICE_ID,
            ITEM_TYPE,
            DESCRIPTION,
            QUANTITY,
            UNIT_PRICE,
            LINE_TOTAL
        )
        SELECT
            P_INVOICE_ID,
            'SERVICE',
            S.SERVICE_NAME,
            J.QUANTITY,
            J.UNIT_PRICE,
            J.QUANTITY * J.UNIT_PRICE
        FROM JOB_CARD_SERVICES J,
             SERVICES S
        WHERE J.SERVICE_ID = S.SERVICE_ID
          AND J.JOB_CARD_ID = P_JOB_CARD_ID
          AND J.LINE_STATUS <> 'CANCELED';


        /* =========================================
           PART ITEMS
           ========================================= */

        INSERT INTO INVOICE_ITEMS
        (
            INVOICE_ID,
            ITEM_TYPE,
            DESCRIPTION,
            QUANTITY,
            UNIT_PRICE,
            LINE_TOTAL
        )
        SELECT
            P_INVOICE_ID,
            'PART',
            P.PART_NAME,
            PI.QUANTITY_ISSUED,
            NVL(PI.UNIT_PRICE,0),
            PI.QUANTITY_ISSUED * NVL(PI.UNIT_PRICE,0)
        FROM PARTS_ISSUED PI,
             PARTS P
        WHERE PI.PART_ID = P.PART_ID
          AND PI.JOB_CARD_ID = P_JOB_CARD_ID;


        /* =========================================
           WASH ITEMS
           ========================================= */

        INSERT INTO INVOICE_ITEMS
        (
            INVOICE_ID,
            ITEM_TYPE,
            DESCRIPTION,
            QUANTITY,
            UNIT_PRICE,
            LINE_TOTAL
        )
        SELECT
            P_INVOICE_ID,
            'WASH',
            'CAR WASH - ' || WASH_TYPE,
            1,
            PRICE,
            PRICE
        FROM CAR_WASH
        WHERE JOB_CARD_ID = P_JOB_CARD_ID;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(
                -20506,
                'User or related data not found.'
            );
    END CREATE_INVOICE;


    PROCEDURE RECALCULATE_INVOICE(
        P_INVOICE_ID      IN INVOICES.INVOICE_ID%TYPE,
        P_DISCOUNT_AMOUNT IN NUMBER
    )
    IS
        V_SUBTOTAL NUMBER := 0;
        V_VAT      NUMBER := 0;
        V_NET      NUMBER := 0;
    BEGIN

        SELECT NVL(SUM(LINE_TOTAL),0)
        INTO V_SUBTOTAL
        FROM INVOICE_ITEMS
        WHERE INVOICE_ID = P_INVOICE_ID;


        IF P_DISCOUNT_AMOUNT < 0
           OR P_DISCOUNT_AMOUNT > V_SUBTOTAL THEN

            RAISE_APPLICATION_ERROR(
                -20507,
                'Invalid discount amount.'
            );

        END IF;


        V_VAT :=
            (V_SUBTOTAL - P_DISCOUNT_AMOUNT) * 0.14;


        V_NET :=
            (V_SUBTOTAL - P_DISCOUNT_AMOUNT) + V_VAT;


        UPDATE INVOICES
        SET SUBTOTAL        = V_SUBTOTAL,
            DISCOUNT_AMOUNT  = P_DISCOUNT_AMOUNT,
            VAT_AMOUNT       = V_VAT,
            NET_TOTAL        = V_NET
        WHERE INVOICE_ID = P_INVOICE_ID;


        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(
                -20508,
                'Invoice not found.'
            );
        END IF;

    END RECALCULATE_INVOICE;


    PROCEDURE GET_INVOICE(
        P_INVOICE_ID IN INVOICES.INVOICE_ID%TYPE,
        P_RESULT     OUT SYS_REFCURSOR
    )
    IS
    BEGIN

        OPEN P_RESULT FOR
            SELECT I.INVOICE_ID,
                   I.INVOICE_DATE,
                   I.SUBTOTAL,
                   I.DISCOUNT_AMOUNT,
                   I.VAT_AMOUNT,
                   I.NET_TOTAL,
                   C.FULL_NAME,
                   C.PHONE,
                   V.PLATE_NUMBER,
                   V.MAKE,
                   V.MODEL
            FROM INVOICES I,
                 JOB_CARDS JC,
                 VEHICLES V,
                 CUSTOMERS C
            WHERE I.JOB_CARD_ID = JC.JOB_CARD_ID
              AND JC.VEHICLE_ID = V.VEHICLE_ID
              AND V.CUSTOMER_ID = C.CUSTOMER_ID
              AND I.INVOICE_ID = P_INVOICE_ID;

    END GET_INVOICE;

END PKG_INVOICE;
/