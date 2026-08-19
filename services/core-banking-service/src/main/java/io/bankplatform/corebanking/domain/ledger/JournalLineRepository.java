package io.bankplatform.corebanking.domain.ledger;

import io.bankplatform.corebanking.domain.ledger.model.JournalLine;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface JournalLineRepository extends JpaRepository<JournalLine, Long> {

    List<JournalLine> findByJournalEntryIdOrderByLineNo(Long journalEntryId);
}
