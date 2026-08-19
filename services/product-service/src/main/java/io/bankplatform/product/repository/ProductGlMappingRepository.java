package io.bankplatform.product.repository;

import io.bankplatform.product.model.ProductGlMapping;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ProductGlMappingRepository extends JpaRepository<ProductGlMapping, Long> {

    List<ProductGlMapping> findByProductId(Long productId);
}
