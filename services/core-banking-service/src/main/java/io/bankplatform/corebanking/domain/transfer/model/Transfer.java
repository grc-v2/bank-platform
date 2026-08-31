package io.bankplatform.corebanking.domain.transfer.model;

import io.bankplatform.common.ddd.AggregateRoot;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import org.hibernate.annotations.Generated;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.generator.EventType;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

/**
 * Aggregate Root đại diện cho lệnh chuyển tiền (schema core_banking).
 */
@Entity
@Table(name = "transfers")
public class Transfer extends AggregateRoot<Long> {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "transfer_reference", nullable = false, unique = true, length = 40)
    private String transferReference;

    @Column(name = "idempotency_key", nullable = false, unique = true, length = 64)
    private String idempotencyKey;

    @Enumerated(EnumType.STRING)
    @Column(name = "transfer_type", nullable = false, length = 20)
    private TransferType transferType;

    @Column(name = "source_account_id", nullable = false)
    private Long sourceAccountId;

    @Column(name = "destination_account_id")
    private Long destinationAccountId;

    @Column(name = "destination_account_number", length = 34)
    private String destinationAccountNumber;

    @Column(name = "destination_bank_code", length = 20)
    private String destinationBankCode;

    @Column(name = "amount", nullable = false, precision = 19, scale = 4)
    private BigDecimal amount;

    @JdbcTypeCode(SqlTypes.CHAR)
    @Column(name = "currency", nullable = false, length = 3)
    private String currency = "VND";

    @Column(name = "fee_amount", nullable = false, precision = 19, scale = 4)
    private BigDecimal feeAmount = BigDecimal.ZERO;

    @Enumerated(EnumType.STRING)
    @Column(name = "channel", nullable = false, length = 20)
    private TransferChannel channel;

    @Column(name = "description", length = 500)
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private TransferStatus status = TransferStatus.PENDING;

    @Column(name = "journal_entry_id")
    private Long journalEntryId;

    @Column(name = "initiated_by_user_id")
    private Long initiatedByUserId;

    @Version
    @Column(name = "version", nullable = false)
    private int version;

    @Generated(event = EventType.INSERT)
    @Column(name = "created_at", insertable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Column(name = "completed_at")
    private OffsetDateTime completedAt;

    @Generated(event = {EventType.INSERT, EventType.UPDATE})
    @Column(name = "updated_at", insertable = false, updatable = false)
    private OffsetDateTime updatedAt;

    protected Transfer() {
    }

    public static Transfer internal(String transferReference, String idempotencyKey, Long sourceAccountId,
                                    Long destinationAccountId, BigDecimal amount, BigDecimal feeAmount,
                                    TransferChannel channel, String description, Long initiatedByUserId) {
        Transfer t = new Transfer();
        t.transferReference = transferReference;
        t.idempotencyKey = idempotencyKey;
        t.transferType = TransferType.INTERNAL;
        t.sourceAccountId = sourceAccountId;
        t.destinationAccountId = destinationAccountId;
        t.destinationAccountNumber = null;
        t.destinationBankCode = null;
        t.amount = amount;
        t.currency = "VND";
        t.feeAmount = feeAmount != null ? feeAmount : BigDecimal.ZERO;
        t.channel = channel;
        t.description = description;
        t.initiatedByUserId = initiatedByUserId;
        t.status = TransferStatus.PENDING;
        return t;
    }

    public static Transfer external(String transferReference, String idempotencyKey, Long sourceAccountId,
                                    String destinationAccountNumber, String destinationBankCode,
                                    BigDecimal amount, BigDecimal feeAmount, TransferChannel channel,
                                    String description, Long initiatedByUserId) {
        Transfer t = new Transfer();
        t.transferReference = transferReference;
        t.idempotencyKey = idempotencyKey;
        t.transferType = TransferType.EXTERNAL;
        t.sourceAccountId = sourceAccountId;
        t.destinationAccountId = null;
        t.destinationAccountNumber = destinationAccountNumber;
        t.destinationBankCode = destinationBankCode;
        t.amount = amount;
        t.currency = "VND";
        t.feeAmount = feeAmount != null ? feeAmount : BigDecimal.ZERO;
        t.channel = channel;
        t.description = description;
        t.initiatedByUserId = initiatedByUserId;
        t.status = TransferStatus.PENDING;
        return t;
    }

    @Override
    public Long getId() {
        return id;
    }

    public String getTransferReference() {
        return transferReference;
    }

    public String getIdempotencyKey() {
        return idempotencyKey;
    }

    public TransferType getTransferType() {
        return transferType;
    }

    public Long getSourceAccountId() {
        return sourceAccountId;
    }

    public Long getDestinationAccountId() {
        return destinationAccountId;
    }

    public String getDestinationAccountNumber() {
        return destinationAccountNumber;
    }

    public String getDestinationBankCode() {
        return destinationBankCode;
    }

    public BigDecimal getAmount() {
        return amount;
    }

    public String getCurrency() {
        return currency;
    }

    public BigDecimal getFeeAmount() {
        return feeAmount;
    }

    public TransferChannel getChannel() {
        return channel;
    }

    public String getDescription() {
        return description;
    }

    public TransferStatus getStatus() {
        return status;
    }

    public void setStatus(TransferStatus status) {
        this.status = status;
    }

    public Long getJournalEntryId() {
        return journalEntryId;
    }

    public void setJournalEntryId(Long journalEntryId) {
        this.journalEntryId = journalEntryId;
    }

    public Long getInitiatedByUserId() {
        return initiatedByUserId;
    }

    public int getVersion() {
        return version;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }

    public OffsetDateTime getCompletedAt() {
        return completedAt;
    }

    public void setCompletedAt(OffsetDateTime completedAt) {
        this.completedAt = completedAt;
    }

    public OffsetDateTime getUpdatedAt() {
        return updatedAt;
    }
}
