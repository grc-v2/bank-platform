package io.bankplatform.product.repository;

import io.bankplatform.product.model.ProductFee;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ProductFeeRepository extends JpaRepository<ProductFee, Long> {

    List<ProductFee> findByProductId(Long productId);
}
