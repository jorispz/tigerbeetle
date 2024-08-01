//////////////////////////////////////////////////////////
// This file was auto-generated by java_bindings.zig
// Do not manually modify.
//////////////////////////////////////////////////////////

package com.tigerbeetle;

public interface TransferFlags {
    int NONE = (int) 0;

    /**
     * @see <a href="https://docs.tigerbeetle.com/reference/transfer#flagslinked">linked</a>
     */
    int LINKED = (int) (1 << 0);

    /**
     * @see <a href="https://docs.tigerbeetle.com/reference/transfer#flagspending">pending</a>
     */
    int PENDING = (int) (1 << 1);

    /**
     * @see <a href="https://docs.tigerbeetle.com/reference/transfer#flagspost_pending_transfer">post_pending_transfer</a>
     */
    int POST_PENDING_TRANSFER = (int) (1 << 2);

    /**
     * @see <a href="https://docs.tigerbeetle.com/reference/transfer#flagsvoid_pending_transfer">void_pending_transfer</a>
     */
    int VOID_PENDING_TRANSFER = (int) (1 << 3);

    /**
     * @see <a href="https://docs.tigerbeetle.com/reference/transfer#flagsbalancing_debit">balancing_debit</a>
     */
    int BALANCING_DEBIT = (int) (1 << 4);

    /**
     * @see <a href="https://docs.tigerbeetle.com/reference/transfer#flagsbalancing_credit">balancing_credit</a>
     */
    int BALANCING_CREDIT = (int) (1 << 5);

    /**
     * @see <a href="https://docs.tigerbeetle.com/reference/transfer#flagsimported">imported</a>
     */
    int IMPORTED = (int) (1 << 6);

    static boolean hasLinked(final int flags) {
        return (flags & LINKED) == LINKED;
    }

    static boolean hasPending(final int flags) {
        return (flags & PENDING) == PENDING;
    }

    static boolean hasPostPendingTransfer(final int flags) {
        return (flags & POST_PENDING_TRANSFER) == POST_PENDING_TRANSFER;
    }

    static boolean hasVoidPendingTransfer(final int flags) {
        return (flags & VOID_PENDING_TRANSFER) == VOID_PENDING_TRANSFER;
    }

    static boolean hasBalancingDebit(final int flags) {
        return (flags & BALANCING_DEBIT) == BALANCING_DEBIT;
    }

    static boolean hasBalancingCredit(final int flags) {
        return (flags & BALANCING_CREDIT) == BALANCING_CREDIT;
    }

    static boolean hasImported(final int flags) {
        return (flags & IMPORTED) == IMPORTED;
    }

}
