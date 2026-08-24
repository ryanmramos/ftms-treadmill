import Toybox.Lang;

class FtmsConnectionPolicy {
    static const STALE_AFTER_MS = 3000;
    static const FIRST_RETRY_DELAY_MS = 1000;
    static const SECOND_RETRY_DELAY_MS = 2000;
    static const THIRD_RETRY_DELAY_MS = 5000;
    static const STEADY_RETRY_DELAY_MS = 10000;

    static function retryDelayMs(attempt as Number) as Number {
        if (attempt == 0) {
            return FIRST_RETRY_DELAY_MS;
        }

        if (attempt == 1) {
            return SECOND_RETRY_DELAY_MS;
        }

        if (attempt == 2) {
            return THIRD_RETRY_DELAY_MS;
        }

        return STEADY_RETRY_DELAY_MS;
    }
}
