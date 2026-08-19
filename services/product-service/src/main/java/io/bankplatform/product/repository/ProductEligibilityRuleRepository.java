package io.bankplatform.product.repository;

import io.bankplatform.product.model.ProductEligibilityRule;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ProductEligibilityRuleRepository extends JpaRepository<ProductEligibilityRule, Long> {

    List<ProductEligibilityRule> findByProductId(Long productId);
}
