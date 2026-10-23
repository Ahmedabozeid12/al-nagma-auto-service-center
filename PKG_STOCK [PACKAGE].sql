
CREATE OR REPLACE PACKAGE PKG_STOCK AS

    PROCEDURE ADD_PART(
        P_PART_CODE       IN PARTS.PART_CODE%TYPE,
        P_PART_NAME       IN PARTS.PART_NAME%TYPE,
        P_CATEGORY        IN PARTS.CATEGORY%TYPE,
        P_UNIT            IN PARTS.UNIT%TYPE,
        P_PURCHASE_PRICE  IN PARTS.PURCHASE_PRICE%TYPE,
        P_SELLING_PRICE   IN PARTS.SELLING_PRICE%TYPE,
        P_REORDER_LEVEL   IN PARTS.REORDER_LEVEL%TYPE,
        P_PART_ID         OUT PARTS.PART_ID%TYPE
    );

    PROCEDURE ADD_RECEIPT(
        P_SUPPLIER_ID      IN RECEIPTS.SUPPLIER_ID%TYPE,
        P_RECEIVED_BY_USER IN RECEIPTS.RECEIVED_BY_USER%TYPE,
        P_NOTES             IN RECEIPTS.NOTES%TYPE,
        P_RECEIPT_ID        OUT RECEIPTS.RECEIPT_ID%TYPE
    );

    PROCEDURE ADD_RECEIPT_ITEM(
        P_RECEIPT_ID       IN RECEIPT_ITEMS.RECEIPT_ID%TYPE,
        P_PART_ID          IN RECEIPT_ITEMS.PART_ID%TYPE,
        P_QUANTITY         IN RECEIPT_ITEMS.QUANTITY%TYPE,
        P_UNIT_COST        IN RECEIPT_ITEMS.UNIT_COST%TYPE,
        P_RECEIPT_ITEM_ID  OUT RECEIPT_ITEMS.RECEIPT_ITEM_ID%TYPE
    );

    PROCEDURE ISSUE_PART(
        P_JOB_CARD_ID       IN PARTS_ISSUED.JOB_CARD_ID%TYPE,
        P_PART_ID           IN PARTS_ISSUED.PART_ID%TYPE,
        P_USER_ID           IN PARTS_ISSUED.ISSUED_BY_USER_ID%TYPE,
        P_QUANTITY          IN PARTS_ISSUED.QUANTITY_ISSUED%TYPE,
        P_PART_ISSUED_ID    OUT PARTS_ISSUED.PART_ISSUED_ID%TYPE
    );

    PROCEDURE GET_LOW_STOCK(
        P_RESULT OUT SYS_REFCURSOR
    );

END PKG_STOCK;
/


CREATE OR REPLACE PACKAGE BODY PKG_STOCK AS

    PROCEDURE ADD_PART(
        P_PART_CODE       IN PARTS.PART_CODE%TYPE,
        P_PART_NAME       IN PARTS.PART_NAME%TYPE,
        P_CATEGORY        IN PARTS.CATEGORY%TYPE,
        P_UNIT            IN PARTS.UNIT%TYPE,
        P_PURCHASE_PRICE  IN PARTS.PURCHASE_PRICE%TYPE,
        P_SELLING_PRICE   IN PARTS.SELLING_PRICE%TYPE,
        P_REORDER_LEVEL   IN PARTS.REORDER_LEVEL%TYPE,
        P_PART_ID         OUT PARTS.PART_ID%TYPE
    )
    IS
    BEGIN

        INSERT INTO PARTS
        (
            PART_CODE,
            PART_NAME,
            CATEGORY,
            UNIT,
            PURCHASE_PRICE,
            SELLING_PRICE,
            REORDER_LEVEL
        )
        VALUES
        (
            P_PART_CODE,
            P_PART_NAME,
            P_CATEGORY,
            P_UNIT,
            P_PURCHASE_PRICE,
            P_SELLING_PRICE,
            P_REORDER_LEVEL
        )
        RETURNING PART_ID INTO P_PART_ID;

    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(
                -20301,
                'Part code already exists.'
            );
    END ADD_PART;


    PROCEDURE ADD_RECEIPT(
        P_SUPPLIER_ID       IN RECEIPTS.SUPPLIER_ID%TYPE,
        P_RECEIVED_BY_USER  IN RECEIPTS.RECEIVED_BY_USER%TYPE,
        P_NOTES             IN RECEIPTS.NOTES%TYPE,
        P_RECEIPT_ID        OUT RECEIPTS.RECEIPT_ID%TYPE
    )
    IS
    BEGIN

        INSERT INTO RECEIPTS
        (
            SUPPLIER_ID,
            RECEIVED_BY_USER,
            NOTES
        )
        VALUES
        (
            P_SUPPLIER_ID,
            P_RECEIVED_BY_USER,
            P_NOTES
        )
        RETURNING RECEIPT_ID INTO P_RECEIPT_ID;

    END ADD_RECEIPT;


    PROCEDURE ADD_RECEIPT_ITEM(
        P_RECEIPT_ID       IN RECEIPT_ITEMS.RECEIPT_ID%TYPE,
        P_PART_ID          IN RECEIPT_ITEMS.PART_ID%TYPE,
        P_QUANTITY         IN RECEIPT_ITEMS.QUANTITY%TYPE,
        P_UNIT_COST        IN RECEIPT_ITEMS.UNIT_COST%TYPE,
        P_RECEIPT_ITEM_ID  OUT RECEIPT_ITEMS.RECEIPT_ITEM_ID%TYPE
    )
    IS
    BEGIN

        INSERT INTO RECEIPT_ITEMS
        (
            RECEIPT_ID,
            PART_ID,
            QUANTITY,
            UNIT_COST
        )
        VALUES
        (
            P_RECEIPT_ID,
            P_PART_ID,
            P_QUANTITY,
            P_UNIT_COST
        )
        RETURNING RECEIPT_ITEM_ID INTO P_RECEIPT_ITEM_ID;

    END ADD_RECEIPT_ITEM;


    PROCEDURE ISSUE_PART(
        P_JOB_CARD_ID       IN PARTS_ISSUED.JOB_CARD_ID%TYPE,
        P_PART_ID           IN PARTS_ISSUED.PART_ID%TYPE,
        P_USER_ID           IN PARTS_ISSUED.ISSUED_BY_USER_ID%TYPE,
        P_QUANTITY          IN PARTS_ISSUED.QUANTITY_ISSUED%TYPE,
        P_PART_ISSUED_ID    OUT PARTS_ISSUED.PART_ISSUED_ID%TYPE
    )
    IS
        V_UNIT_COST PARTS.PURCHASE_PRICE%TYPE;
        V_UNIT_PRICE PARTS.SELLING_PRICE%TYPE;
    BEGIN

        SELECT PURCHASE_PRICE,
               SELLING_PRICE
        INTO V_UNIT_COST,
             V_UNIT_PRICE
        FROM PARTS
        WHERE PART_ID = P_PART_ID;

        INSERT INTO PARTS_ISSUED
        (
            JOB_CARD_ID,
            PART_ID,
            ISSUED_BY_USER_ID,
            QUANTITY_ISSUED,
            UNIT_COST,
            UNIT_PRICE
        )
        VALUES
        (
            P_JOB_CARD_ID,
            P_PART_ID,
            P_USER_ID,
            P_QUANTITY,
            V_UNIT_COST,
            V_UNIT_PRICE
        )
        RETURNING PART_ISSUED_ID INTO P_PART_ISSUED_ID;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(
                -20302,
                'Part not found.'
            );
    END ISSUE_PART;


    PROCEDURE GET_LOW_STOCK(
        P_RESULT OUT SYS_REFCURSOR
    )
    IS
    BEGIN

        OPEN P_RESULT FOR
            SELECT PART_ID,
                   PART_CODE,
                   PART_NAME,
                   CATEGORY,
                   UNIT,
                   QUANTITY_ON_HAND,
                   REORDER_LEVEL,
                   SELLING_PRICE
            FROM PARTS
            WHERE QUANTITY_ON_HAND <= REORDER_LEVEL
            ORDER BY QUANTITY_ON_HAND;

    END GET_LOW_STOCK;

END PKG_STOCK;
/