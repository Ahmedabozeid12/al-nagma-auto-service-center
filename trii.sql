CREATE OR REPLACE TRIGGER HE.TRG_PARTS_ISSUED_CHECK
BEFORE INSERT OR UPDATE ON HE.PARTS_ISSUED
FOR EACH ROW
DECLARE
    V_STOCK NUMBER;
BEGIN
    SELECT QUANTITY_ON_HAND
      INTO V_STOCK
      FROM HE.PARTS
     WHERE PART_ID = :NEW.PART_ID
       FOR UPDATE;

    -- ›Ì Õ«·…  ⁄œÌ· ⁄„·Ì… ’—› ﬁœÌ„… ·‰›” «·’‰›
    IF UPDATING AND :OLD.PART_ID = :NEW.PART_ID THEN
        V_STOCK := V_STOCK + :OLD.QUANTITY_ISSUED;
    END IF;

    IF :NEW.QUANTITY_ISSUED <= 0 THEN
        RAISE_APPLICATION_ERROR(
            -20001,
            'Quantity must be greater than zero.'
        );
    END IF;

    IF V_STOCK - :NEW.QUANTITY_ISSUED <= 1 THEN
        RAISE_APPLICATION_ERROR(
            -20002,
            'Cannot issue this quantity. At least 2 items must remain in stock.'
        );
    END IF;
END;
/