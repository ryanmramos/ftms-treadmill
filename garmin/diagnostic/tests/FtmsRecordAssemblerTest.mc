import Toybox.Lang;
import Toybox.Test;

class FtmsRecordAssemblerTest {
    (:test)
    static function testSingleNotificationCompletesImmediately(
        logger as Test.Logger
    ) as Boolean {
        var assembler = new FtmsRecordAssembler();
        var sample = assembler.append([0x00, 0x00, 0x20, 0x03]b, 1000);

        Test.assertMessage(sample != null, "single notification should complete");
        if (sample == null) {
            return false;
        }
        Test.assertMessage(sample.speedMps != null, "speed decoded");
        Test.assertMessage(!assembler.hasIncompleteRecord(), "no pending record");

        return true;
    }

    (:test)
    static function testMoreDataMergesFieldsIntoFinalNotification(
        logger as Test.Logger
    ) as Boolean {
        var assembler = new FtmsRecordAssembler();

        // More Data + total distance 10000 m, no speed
        var first = assembler.append([0x05, 0x00, 0x10, 0x27, 0x00]b, 2000);
        Test.assertMessage(first == null, "More Data fragment is incomplete");
        Test.assertMessage(assembler.hasIncompleteRecord(), "fragment should be held");

        // final notification: speed 8.00 km/h
        var sample = assembler.append([0x00, 0x00, 0x20, 0x03]b, 2001);
        Test.assertMessage(sample != null, "final notification should complete");
        if (sample == null) {
            return false;
        }
        Test.assertMessage(sample.speedMps != null, "speed from final fragment");
        Test.assertEqualMessage(10000.0, sample.totalDistanceM, "distance from earlier fragment");
        Test.assertEqualMessage(0x0004, sample.flags, "merged flags without More Data");
        Test.assertEqualMessage(2001, sample.receivedAtMs, "completion time");
        Test.assertEqualMessage(9, sample.rawLength, "total bytes");
        Test.assertMessage(!assembler.hasIncompleteRecord(), "pending cleared");

        return true;
    }

    (:test)
    static function testBrokenEarlierFragmentInvalidatesRecord(
        logger as Test.Logger
    ) as Boolean {
        var assembler = new FtmsRecordAssembler();

        // More Data + total distance, but only one of three distance bytes
        assembler.append([0x05, 0x00, 0x10]b, 2500);
        var sample = assembler.append([0x00, 0x00, 0x20, 0x03]b, 2501);

        Test.assertMessage(sample != null, "record completes");
        if (sample == null) {
            return false;
        }
        Test.assertMessage(!sample.isValid(), "earlier parse error carries over");

        return true;
    }

    (:test)
    static function testDisconnectDiscardsIncompleteRecord(
        logger as Test.Logger
    ) as Boolean {
        var assembler = new FtmsRecordAssembler();

        assembler.append([0x05, 0x00, 0x10, 0x27, 0x00]b, 3000);
        assembler.discard();

        Test.assertMessage(
            !assembler.hasIncompleteRecord(),
            "disconnect must discard incomplete record"
        );

        var sample = assembler.append([0x00, 0x00, 0x10, 0x00]b, 4000);
        Test.assertMessage(sample != null, "new record should start cleanly");
        if (sample == null) {
            return false;
        }
        Test.assertMessage(sample.totalDistanceM == null, "old fragment must not leak");

        return true;
    }
}
