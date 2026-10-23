
CREATE OR REPLACE PACKAGE PKG_JOB_WORKFLOW AS

    PROCEDURE CHANGE_STATUS(
        P_JOB_CARD_ID   IN NUMBER,
        P_NEW_STATUS    IN VARCHAR2
    );
END PKG_JOB_WORKFLOW;

CREATE OR REPLACE PACKAGE BODY PKG_JOB_WORKFLOW AS

    PROCEDURE CHANGE_STATUS(
        P_JOB_CARD_ID   IN NUMBER,
        P_NEW_STATUS    IN VARCHAR2
    )
    IS
        V_STATUS_ID NUMBER;
        V_NEW_STATUS_ID NUMBER;
        V_STATUS_NAME VARCHAR2(50);
    BEGIN
        IF P_JOB_CARD_ID IS NULL OR P_NEW_STATUS IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20020,
                'Job card ID and new status are required.'
            );
        END IF;

        SELECT STATUS_ID
          INTO V_STATUS_ID
          FROM JOB_CARDS
         WHERE JOB_CARD_ID = P_JOB_CARD_ID
         FOR UPDATE;

        SELECT STATUS_ID, STATUS_NAME
          INTO V_NEW_STATUS_ID, V_STATUS_NAME
          FROM JOB_STATUS
         WHERE UPPER(STATUS_NAME) = UPPER(TRIM(P_NEW_STATUS));

        UPDATE JOB_CARDS
           SET STATUS_ID = V_NEW_STATUS_ID
         WHERE JOB_CARD_ID = P_JOB_CARD_ID;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(
                -20021,
                'Job card or requested status was not found.'
            );

        WHEN TOO_MANY_ROWS THEN
            RAISE_APPLICATION_ERROR(
                -20022,
                'Duplicate status names were found.'
            );
    END CHANGE_STATUS;

END PKG_JOB_WORKFLOW;
