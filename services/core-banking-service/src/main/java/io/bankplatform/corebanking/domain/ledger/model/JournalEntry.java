package io.bankplatform.corebanking.domain.ledger.model;

import io.bankplatform.common.ddd.AggregateRoot;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.OneToMany;
import jakarta.persistence.Table;
import org.hibernate.annotations.Generated;
import org.hibernate.generator.EventType;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * Aggregate Root đại diện cho header bút toán sổ cái (schema core_banking).
 * Append-only tuyệt đối: không có setter.
 */
@Entity
@Table(name = "journal_entries")
public class JournalEntry extends AggregateRoot<Long> {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "entry_reference", nullable = false, unique = true, length = 40)
    private String entryReference;

    @Enumerated(EnumType.STRING)
    @Column(name = "transaction_type", nullable = false, length = 20)
    private TransactionType transactionType;

    @Column(name = "source_type", length = 30)
    private String sourceType;

    @Column(name = "source_id", length = 100)
    private String sourceId;

    @Column(name = "value_date", nullable = false)
    private LocalDate valueDate;

    @Column(name = "booking_date", nullable = false)
    private LocalDate bookingDate;

    @Generated(event = EventType.INSERT)
    @Column(name = "posted_at", insertable = false, updatable = false)
    private OffsetDateTime postedAt;

    @Column(name = "description", length = 500)
    private String description;

    @Column(name = "reversal_of_entry_id")
    private Long reversalOfEntryId;

    @Generated(event = EventType.INSERT)
    @Column(name = "created_at", insertable = false, updatable = false)
    private OffsetDateTime createdAt;

    @OneToMany(mappedBy = "journalEntry", cascade = CascadeType.PERSIST, fetch = FetchType.LAZY)
    private List<JournalLine> lines = new ArrayList<>();

    protected JournalEntry() {
    }

    public JournalEntry(String entryReference, TransactionType transactionType, String sourceType,
                        String sourceId, LocalDate valueDate, LocalDate bookingDate,
                        String description, Long reversalOfEntryId) {
        this.entryReference = entryReference;
        this.transactionType = transactionType;
        this.sourceType = sourceType;
        this.sourceId = sourceId;
        this.valueDate = valueDate != null ? valueDate : LocalDate.now();
        this.bookingDate = bookingDate != null ? bookingDate : LocalDate.now();
        this.description = description;
        this.reversalOfEntryId = reversalOfEntryId;
    }

    @Override
    public Long getId() {
        return id;
    }

    public String getEntryReference() {
        return entryReference;
    }

    public TransactionType getTransactionType() {
        return transactionType;
    }

    public String getSourceType() {
        return sourceType;
    }

    public String getSourceId() {
        return sourceId;
    }

    public LocalDate getValueDate() {
        return valueDate;
    }

    public LocalDate getBookingDate() {
        return bookingDate;
    }

    public OffsetDateTime getPostedAt() {
        return postedAt;
    }

    public String getDescription() {
        return description;
    }

    public Long getReversalOfEntryId() {
        return reversalOfEntryId;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }

    public List<JournalLine> getLines() {
        return lines;
    }

    public void addLine(JournalLine line) {
        if (line != null) {
            lines.add(line);
            line.setJournalEntry(this);
        }
    }
}
