
CREATE OR REPLACE PACKAGE PKG_PAYMENT AS

    PROCEDURE ADD_PAYMENT(
        P_INVOICE_ID       IN PAYMENTS.INVOICE_ID%TYPE,
        P_PAYMENT_METHOD_ID IN PAYMENTS.PAYMENT_METHOD_ID%TYPE,
        P_AMOUNT           IN PAYMENTS.AMOUNT%TYPE,
        P_USER_ID          IN PAYMENTS.RECEIVED_BY_USER_ID%TYPE,
        P_NOTES            IN PAYMENTS.NOTES%TYPE DEFAULT NULL,
        P_PAYMENT_ID       OUT PAYMENTS.PAYMENT_ID%TYPE
    );

    PROCEDURE GET_PAID_AMOUNT(
        P_INVOICE_ID       IN PAYMENTS.INVOICE_ID%TYPE,
        P_PAID_AMOUNT      OUT NUMBER
    );

    PROCEDURE GET_REMAINING_AMOUNT(
        P_INVOICE_ID       IN PAYMENTS.INVOICE_ID%TYPE,
        P_REMAINING_AMOUNT OUT NUMBER
    );

END PKG_PAYMENT;
/


CREATE OR REPLACE PACKAGE BODY PKG_PAYMENT AS

    PROCEDURE ADD_PAYMENT(
        P_INVOICE_ID        IN PAYMENTS.INVOICE_ID%TYPE,
        P_PAYMENT_METHOD_ID IN PAYMENTS.PAYMENT_METHOD_ID%TYPE,
        P_AMOUNT            IN PAYMENTS.AMOUNT%TYPE,
        P_USER_ID           IN PAYMENTS.RECEIVED_BY_USER_ID%TYPE,
        P_NOTES             IN PAYMENTS.NOTES%TYPE DEFAULT NULL,
        P_PAYMENT_ID        OUT PAYMENTS.PAYMENT_ID%TYPE
    )
    IS
        V_NET_TOTAL NUMBER;
        V_PAID NUMBER;
        V_REMAINING NUMBER;
    BEGIN

        SELECT NET_TOTAL
        INTO V_NET_TOTAL
        FROM INVOICES
        WHERE INVOICE_ID = P_INVOICE_ID
        FOR UPDATE;


        SELECT NVL(SUM(AMOUNT),0)
        INTO V_PAID
        FROM PAYMENTS
        WHERE INVOICE_ID = P_INVOICE_ID;


        V_REMAINING := V_NET_TOTAL - V_PAID;


        IF P_AMOUNT <= 0 THEN
            RAISE_APPLICATION_ERROR(
                -20601,
                'Payment amount must be greater than zero.'
            );
        END IF;


        IF P_AMOUNT > V_REMAINING THEN
            RAISE_APPLICATION_ERROR(
                -20602,
                'Payment cannot exceed remaining balance. Remaining = '
                || V_REMAINING
            );
        END IF;


        INSERT INTO PAYMENTS
        (
            INVOICE_ID,
            PAYMENT_METHOD_ID,
            AMOUNT,
            RECEIVED_BY_USER_ID,
            NOTES
        )
        VALUES
        (
            P_INVOICE_ID,
            P_PAYMENT_METHOD_ID,
            P_AMOUNT,
            P_USER_ID,
            P_NOTES
        )
        RETURNING PAYMENT_ID INTO P_PAYMENT_ID;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(
                -20603,
                'Invoice not found.'
            );
    END ADD_PAYMENT;


    PROCEDURE GET_PAID_AMOUNT(
        P_INVOICE_ID  IN PAYMENTS.INVOICE_ID%TYPE,
        P_PAID_AMOUNT OUT NUMBER
    )
    IS
    BEGIN

        SELECT NVL(SUM(AMOUNT),0)
        INTO P_PAID_AMOUNT
        FROM PAYMENTS
        WHERE INVOICE_ID = P_INVOICE_ID;

    END GET_PAID_AMOUNT;


    PROCEDURE GET_REMAINING_AMOUNT(
        P_INVOICE_ID       IN PAYMENTS.INVOICE_ID%TYPE,
        P_REMAINING_AMOUNT OUT NUMBER
    )
    IS
        V_NET_TOTAL NUMBER;
        V_PAID NUMBER;
    BEGIN

        SELECT NET_TOTAL
        INTO V_NET_TOTAL
        FROM INVOICES
        WHERE INVOICE_ID = P_INVOICE_ID;

        SELECT NVL(SUM(AMOUNT),0)
        INTO V_PAID
        FROM PAYMENTS
        WHERE INVOICE_ID = P_INVOICE_ID;

        P_REMAINING_AMOUNT := V_NET_TOTAL - V_PAID;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(
                -20604,
                'Invoice not found.'
            );
    END GET_REMAINING_AMOUNT;

END PKG_PAYMENT;
/