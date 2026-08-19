package io.bankplatform.corebanking.domain.ledger;

import io.bankplatform.corebanking.domain.ledger.model.JournalEntry;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface JournalEntryRepository extends JpaRepository<JournalEntry, Long> {

    Optional<JournalEntry> findByEntryReference(String entryReference);
}
