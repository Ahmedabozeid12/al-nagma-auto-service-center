CREATE OR REPLACE TRIGGER HE.TRG_RECEIPT_ITEM_STOCK_UPD
AFTER UPDATE OF QUANTITY, PART_ID
ON HE.RECEIPT_ITEMS
FOR EACH ROW
BEGIN
    IF :NEW.PART_ID = :OLD.PART_ID THEN

        -- ‰›” «·’‰›: ⁄œ¯· «·—’Ìœ »›—ﬁ «·ﬂ„Ì…
        UPDATE HE.PARTS
           SET QUANTITY_ON_HAND =
               QUANTITY_ON_HAND
               + (:NEW.QUANTITY - :OLD.QUANTITY)
         WHERE PART_ID = :OLD.PART_ID
           AND QUANTITY_ON_HAND
               + (:NEW.QUANTITY - :OLD.QUANTITY) >= 0;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(
                -20311,
                'Update rejected: insufficient stock or part not found.'
            );
        END IF;

    ELSE

        -- ’‰› „Œ ·›: «—Ã⁄ «·ﬂ„Ì… «·ﬁœÌ„… ··’‰› «·ﬁœÌ„
        UPDATE HE.PARTS
           SET QUANTITY_ON_HAND =
               QUANTITY_ON_HAND - :OLD.QUANTITY
         WHERE PART_ID = :OLD.PART_ID
           AND QUANTITY_ON_HAND >= :OLD.QUANTITY;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(
                -20312,
                'Cannot change part: old part stock is insufficient.'
            );
        END IF;

        -- √÷› «·ﬂ„Ì… «·ÃœÌœ… ··’‰› «·ÃœÌœ
        UPDATE HE.PARTS
           SET QUANTITY_ON_HAND =
               QUANTITY_ON_HAND + :NEW.QUANTITY
         WHERE PART_ID = :NEW.PART_ID;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(
                -20313,
                'New part not found.'
            );
        END IF;

    END IF;
END;
/