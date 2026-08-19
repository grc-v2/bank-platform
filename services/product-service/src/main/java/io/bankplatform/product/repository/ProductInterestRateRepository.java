package io.bankplatform.product.repository;

import io.bankplatform.product.model.ProductInterestRate;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ProductInterestRateRepository extends JpaRepository<ProductInterestRate, Long> {

    List<ProductInterestRate> findByProductId(Long productId);
}
