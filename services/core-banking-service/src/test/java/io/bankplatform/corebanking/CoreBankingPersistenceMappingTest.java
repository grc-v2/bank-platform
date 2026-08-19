package io.bankplatform.corebanking;

import io.bankplatform.corebanking.domain.account.*;
import io.bankplatform.corebanking.domain.account.model.*;
import io.bankplatform.corebanking.domain.ledger.*;
import io.bankplatform.corebanking.domain.ledger.model.*;
import io.bankplatform.corebanking.domain.shared.AuditLogRepository;
import io.bankplatform.corebanking.domain.shared.model.AuditLog;
import io.bankplatform.corebanking.domain.transfer.*;
import io.bankplatform.corebanking.domain.transfer.model.*;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

@Transactional
class CoreBankingPersistenceMappingTest extends AbstractIntegrationTest {

    @Autowired
    private GlAccountRepository glAccounts;

    @Autowired
    private AccountRepository accounts;

    @Autowired
    private AccountHoldRepository accountHolds;

    @Autowired
    private JournalEntryRepository journalEntries;

    @Autowired
    private JournalLineRepository journalLines;

    @Autowired
    private TransferRepository transfers;

    @Autowired
    private ExternalTransferRepository externalTransfers;

    @Autowired
    private TransferLimitUsageRepository limitUsages;

    @Autowired
    private AccountBalanceSnapshotRepository snapshots;

    @Autowired
    private InterestAccrualRepository interestAccruals;

    @Autowired
    private FeeChargeRepository feeCharges;

    @Autowired
    private AuditLogRepository auditLogs;

    @Autowired
    private EntityManager em;

    @Test
    void readSeedGlAccount_2010() {
        GlAccount gl2010 = glAccounts.findByGlCode("2010")
                .orElseThrow(() -> new AssertionError("Seed GL 2010 không tìm thấy"));

        assertThat(gl2010.getName()).isEqualTo("Tiền gửi khách hàng - thanh toán");
        assertThat(gl2010.getAccountClass()).isEqualTo(GlAccountClass.LIABILITY);
        assertThat(gl2010.getNormalBalance()).isEqualTo(NormalBalance.CREDIT);
    }

    @Test
    void saveAccountWithHolders_andOptimisticLock() {
        Account acc = new Account(
                "ACC_100200300",
                "CA_STANDARD",
                1001L,
                "VND",
                "2010",
                new BigDecimal("500000.0000"),
                new BigDecimal("200000.0000"),
                BigDecimal.ZERO
        );
        acc.addHolder(1001L, HolderRole.PRIMARY);

        acc = accounts.saveAndFlush(acc);
        Long accountId = acc.getId();

        assertThat(acc.getAvailableBalance()).isEqualByComparingTo(new BigDecimal("300000.0000"));
        assertThat(acc.getVersion()).isEqualTo(0);
        assertThat(acc.getCreatedAt()).isNotNull();

        em.clear();

        Account fetched = accounts.findByAccountNumber("ACC_100200300").orElseThrow();
        assertThat(fetched.getId()).isEqualTo(accountId);
        assertThat(fetched.getHolders()).hasSize(1);

        fetched.setLedgerBalance(new BigDecimal("600000.0000"));
        fetched = accounts.saveAndFlush(fetched);
        assertThat(fetched.getVersion()).isEqualTo(1);
    }

    @Test
    void saveAccountHold_roundTrip() {
        Account acc = accounts.saveAndFlush(new Account(
                "ACC_HOLD_TEST", "CA_STANDARD", 1002L, "VND", "2010",
                new BigDecimal("1000000.0000"), BigDecimal.ZERO, BigDecimal.ZERO
        ));

        AccountHold hold = new AccountHold(
                acc.getId(),
                new BigDecimal("100000.0000"),
                HoldReason.TRANSFER,
                "TRANSFER",
                "REF_HOLD_001",
                OffsetDateTime.now().plusHours(1)
        );
        hold = accountHolds.saveAndFlush(hold);
        Long holdId = hold.getId();

        em.clear();

        List<AccountHold> activeHolds = accountHolds.findByAccountIdAndStatus(acc.getId(), HoldStatus.ACTIVE);
        assertThat(activeHolds).hasSize(1);
        assertThat(activeHolds.get(0).getId()).isEqualTo(holdId);
        assertThat(activeHolds.get(0).getAmount()).isEqualByComparingTo(new BigDecimal("100000.0000"));
        assertThat(activeHolds.get(0).getPlacedAt()).isNotNull();
    }

    @Test
    void saveJournalEntryWithLines_roundTrip() {
        Account acc = accounts.saveAndFlush(new Account(
                "ACC_JOURNAL_TEST", "CA_STANDARD", 1003L, "VND", "2010",
                new BigDecimal("1000000.0000"), BigDecimal.ZERO, BigDecimal.ZERO
        ));

        JournalEntry entry = new JournalEntry(
                "JRN_TEST_001",
                TransactionType.TRANSFER,
                "TRANSFER",
                "TRF_001",
                LocalDate.now(),
                LocalDate.now(),
                "Chuyển tiền test",
                null
        );

        JournalLine debitLine = new JournalLine(
                1,
                acc.getId(),
                "2010",
                LedgerDirection.DEBIT,
                new BigDecimal("100000.0000"),
                "VND",
                new BigDecimal("900000.0000")
        );
        JournalLine creditLine = new JournalLine(
                2,
                null,
                "4010",
                LedgerDirection.CREDIT,
                new BigDecimal("100000.0000"),
                "VND",
                null
        );

        entry.addLine(debitLine);
        entry.addLine(creditLine);

        entry = journalEntries.saveAndFlush(entry);
        Long entryId = entry.getId();

        em.clear();

        JournalEntry fetched = journalEntries.findByEntryReference("JRN_TEST_001").orElseThrow();
        assertThat(fetched.getId()).isEqualTo(entryId);
        assertThat(fetched.getPostedAt()).isNotNull();
        assertThat(fetched.getCreatedAt()).isNotNull();

        List<JournalLine> lines = journalLines.findByJournalEntryIdOrderByLineNo(entryId);
        assertThat(lines).hasSize(2);
        assertThat(lines.get(0).getLineNo()).isEqualTo(1);
        assertThat(lines.get(0).getDirection()).isEqualTo(LedgerDirection.DEBIT);
        assertThat(lines.get(0).getCreatedAt()).isNotNull();
        assertThat(lines.get(1).getLineNo()).isEqualTo(2);
        assertThat(lines.get(1).getDirection()).isEqualTo(LedgerDirection.CREDIT);
    }

    @Test
    void saveTransferAndExternalTransfer_roundTrip() {
        Account srcAcc = accounts.saveAndFlush(new Account(
                "ACC_SRC_001", "CA_STANDARD", 1004L, "VND", "2010",
                new BigDecimal("1000000.0000"), BigDecimal.ZERO, BigDecimal.ZERO
        ));
        Account destAcc = accounts.saveAndFlush(new Account(
                "ACC_DEST_001", "CA_STANDARD", 1005L, "VND", "2010",
                new BigDecimal("500000.0000"), BigDecimal.ZERO, BigDecimal.ZERO
        ));

        Transfer internalTrf = Transfer.internal(
                "TRF_INT_001",
                "IDEM_INT_001",
                srcAcc.getId(),
                destAcc.getId(),
                new BigDecimal("200000.0000"),
                BigDecimal.ZERO,
                TransferChannel.MOBILE,
                "Chuyển nội bộ test",
                1004L
        );
        transfers.saveAndFlush(internalTrf);

        Transfer externalTrf = Transfer.external(
                "TRF_EXT_001",
                "IDEM_EXT_001",
                srcAcc.getId(),
                "970412345678",
                "VCB",
                new BigDecimal("300000.0000"),
                new BigDecimal("5500.0000"),
                TransferChannel.MOBILE,
                "Chuyển liên ngân hàng test",
                1004L
        );
        externalTrf = transfers.saveAndFlush(externalTrf);

        ExternalTransfer saga = new ExternalTransfer(
                externalTrf.getId(),
                "NAPAS",
                "PARTNER_REF_001",
                SagaState.HOLD_PLACED,
                "PARTNER_IDEM_001",
                OffsetDateTime.now().plusMinutes(5)
        );
        externalTransfers.saveAndFlush(saga);

        em.clear();

        Transfer fetchedInternal = transfers.findByIdempotencyKey("IDEM_INT_001").orElseThrow();
        assertThat(fetchedInternal.getTransferReference()).isEqualTo("TRF_INT_001");
        assertThat(fetchedInternal.getStatus()).isEqualTo(TransferStatus.PENDING);

        Transfer fetchedExternal = transfers.findByTransferReference("TRF_EXT_001").orElseThrow();
        assertThat(fetchedExternal.getStatus()).isEqualTo(TransferStatus.PENDING);

        ExternalTransfer fetchedSaga = externalTransfers.findByTransferId(fetchedExternal.getId()).orElseThrow();
        assertThat(fetchedSaga.getSagaState()).isEqualTo(SagaState.HOLD_PLACED);
        assertThat(fetchedSaga.getPartnerCode()).isEqualTo("NAPAS");
    }

    @Test
    void saveSnapshotsAccrualsFeesUsagesAndAuditLog_roundTrip() {
        Account acc = accounts.saveAndFlush(new Account(
                "ACC_MISC_TEST", "CA_STANDARD", 1006L, "VND", "2010",
                new BigDecimal("1000000.0000"), BigDecimal.ZERO, BigDecimal.ZERO
        ));

        LocalDate today = LocalDate.now();

        AccountBalanceSnapshot snap = new AccountBalanceSnapshot(
                acc.getId(),
                today,
                new BigDecimal("500000.0000"),
                new BigDecimal("1000000.0000"),
                new BigDecimal("200000.0000"),
                new BigDecimal("700000.0000")
        );
        snapshots.saveAndFlush(snap);

        InterestAccrual accrual = new InterestAccrual(
                acc.getId(),
                today,
                new BigDecimal("1000000.0000"),
                new BigDecimal("0.001000"),
                new BigDecimal("27.3973")
        );
        interestAccruals.saveAndFlush(accrual);

        FeeCharge fee = new FeeCharge(
                acc.getId(),
                "MAINT_MONTHLY",
                "SYSTEM",
                "JOB_EOM",
                new BigDecimal("11000.0000"),
                "VND",
                FeeChargeStatus.PENDING
        );
        feeCharges.saveAndFlush(fee);

        TransferLimitUsage usage = new TransferLimitUsage(
                acc.getId(),
                "TRF_PER_DAY",
                today,
                new BigDecimal("500000000.0000"),
                2
        );
        limitUsages.saveAndFlush(usage);

        AuditLog audit = new AuditLog(
                999L,
                "CREATE_ACCOUNT",
                "ACCOUNT",
                acc.getId().toString(),
                "{\"status\":\"PENDING\"}"
        );
        auditLogs.saveAndFlush(audit);

        em.clear();

        AccountBalanceSnapshot fetchedSnap = snapshots.findById(new AccountBalanceSnapshotId(acc.getId(), today)).orElseThrow();
        assertThat(fetchedSnap.getClosingBalance()).isEqualByComparingTo(new BigDecimal("1000000.0000"));
        assertThat(fetchedSnap.getCreatedAt()).isNotNull();

        InterestAccrual fetchedAccrual = interestAccruals.findByAccountIdAndAccrualDate(acc.getId(), today).orElseThrow();
        assertThat(fetchedAccrual.getAccruedAmount()).isEqualByComparingTo(new BigDecimal("27.3973"));

        List<FeeCharge> fetchedFees = feeCharges.findByAccountIdOrderByChargedAtDesc(acc.getId());
        assertThat(fetchedFees).hasSize(1);
        assertThat(fetchedFees.get(0).getFeeCode()).isEqualTo("MAINT_MONTHLY");

        TransferLimitUsage fetchedUsage = limitUsages.findByAccountIdAndLimitCodeAndWindowStart(acc.getId(), "TRF_PER_DAY", today).orElseThrow();
        assertThat(fetchedUsage.getUsedCount()).isEqualTo(2);

        List<AuditLog> allAudit = auditLogs.findAll();
        assertThat(allAudit).isNotEmpty();
        assertThat(allAudit.get(0).getOccurredAt()).isNotNull();
    }
}
