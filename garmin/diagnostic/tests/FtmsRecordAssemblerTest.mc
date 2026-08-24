import Toybox.Lang;
import Toybox.Test;

class FtmsRecordAssemblerTest {
    (:test)
    static function testSingleNotificationCompletesImmediately(
        logger as Test.Logger
    ) as Boolean {
        var assembler = new FtmsRecordAssembler();
        var record = assembler.append([0x00, 0x00, 0x20, 0x03]b, 1000);

        Test.assertMessage(record != null, "single notification should complete");
        if (record == null) {
            return false;
        }
        Test.assertEqualMessage(1, record.fragmentCount(), "fragment count");
        Test.assertMessage(record.isSingleNotification(), "single notification record");
        Test.assertMessage(!assembler.hasIncompleteRecord(), "no pending record");

        return true;
    }

    (:test)
    static function testMoreDataWaitsForFinalNotification(
        logger as Test.Logger
    ) as Boolean {
        var assembler = new FtmsRecordAssembler();

        var first = assembler.append([0x01, 0x00, 0xAA]b, 2000);
        Test.assertMessage(first == null, "More Data fragment is incomplete");
        Test.assertMessage(assembler.hasIncompleteRecord(), "fragment should be retained");

        var complete = assembler.append([0x00, 0x00, 0x20, 0x03]b, 2001);
        Test.assertMessage(complete != null, "final notification should complete");
        if (complete == null) {
            return false;
        }
        Test.assertEqualMessage(2, complete.fragmentCount(), "fragment count");
        Test.assertMessage(!complete.isSingleNotification(), "record is fragmented");

        return true;
    }

    (:test)
    static function testDisconnectDiscardsIncompleteRecord(
        logger as Test.Logger
    ) as Boolean {
        var assembler = new FtmsRecordAssembler();

        assembler.append([0x01, 0x00, 0xAA]b, 3000);
        assembler.discard();

        Test.assertMessage(
            !assembler.hasIncompleteRecord(),
            "disconnect must discard incomplete record"
        );

        var newRecord = assembler.append([0x00, 0x00, 0x10, 0x00]b, 4000);
        Test.assertMessage(newRecord != null, "new record should start cleanly");
        if (newRecord == null) {
            return false;
        }
        Test.assertEqualMessage(1, newRecord.fragmentCount(), "old fragment must not leak");

        return true;
    }
}
