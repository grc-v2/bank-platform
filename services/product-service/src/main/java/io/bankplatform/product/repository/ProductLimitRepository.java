package io.bankplatform.product.repository;

import io.bankplatform.product.model.ProductLimit;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ProductLimitRepository extends JpaRepository<ProductLimit, Long> {

    List<ProductLimit> findByProductId(Long productId);
}
