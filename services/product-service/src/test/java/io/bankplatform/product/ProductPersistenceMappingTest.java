package io.bankplatform.product;

import io.bankplatform.product.model.*;
import io.bankplatform.product.repository.*;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

@Transactional
class ProductPersistenceMappingTest extends AbstractIntegrationTest {

    @Autowired
    private ProductRepository products;

    @Autowired
    private ProductInterestRateRepository interestRates;

    @Autowired
    private ProductFeeRepository fees;

    @Autowired
    private ProductLimitRepository limits;

    @Autowired
    private ProductEligibilityRuleRepository rules;

    @Autowired
    private ProductGlMappingRepository glMappings;

    @Autowired
    private EntityManager em;

    @Test
    void readSeedProduct_CaStandard() {
        Product ca = products.findByProductCode("CA_STANDARD")
                .orElseThrow(() -> new AssertionError("Seed product CA_STANDARD không tìm thấy"));

        assertThat(ca.getId()).isNotNull();
        assertThat(ca.getName()).isEqualTo("Tài khoản thanh toán chuẩn");
        assertThat(ca.getCategory()).isEqualTo(ProductCategory.CURRENT_ACCOUNT);
        assertThat(ca.getCurrency()).isEqualTo("VND");
        assertThat(ca.getStatus()).isEqualTo(ProductStatus.ACTIVE);
        assertThat(ca.getCreatedAt()).isNotNull();
        assertThat(ca.getUpdatedAt()).isNotNull();
    }

    @Test
    void productWithAllChildTables_roundTrip() {
        Product prod = new Product(
                "TEST_PROD",
                "Sản phẩm dùng cho Test",
                ProductCategory.CURRENT_ACCOUNT,
                "VND",
                ProductStatus.DRAFT,
                "Mô tả sản phẩm test",
                LocalDate.now(),
                null
        );
        prod = products.saveAndFlush(prod);
        Long productId = prod.getId();

        ProductInterestRate rate = new ProductInterestRate(
                productId,
                BigDecimal.ZERO,
                null,
                null,
                new BigDecimal("0.012000"),
                LocalDate.now(),
                null
        );
        interestRates.saveAndFlush(rate);

        ProductFee fee = new ProductFee(
                productId,
                "FEE_TEST",
                FeeType.FLAT,
                new BigDecimal("5000.0000"),
                null,
                null,
                null,
                ChargeEvent.MONTHLY_MAINTENANCE,
                "VND",
                LocalDate.now(),
                null
        );
        fees.saveAndFlush(fee);

        ProductLimit limit = new ProductLimit(
                productId,
                "LIM_TEST",
                LimitScope.PER_DAY,
                LimitChannel.ANY,
                new BigDecimal("1000000000.0000"),
                20,
                "VND",
                LocalDate.now(),
                null
        );
        limits.saveAndFlush(limit);

        ProductEligibilityRule rule = new ProductEligibilityRule(
                productId,
                EligibilityRuleType.MIN_AGE,
                RuleOperator.GTE,
                "18"
        );
        rules.saveAndFlush(rule);

        ProductGlMapping glMapping = new ProductGlMapping(
                productId,
                GlMappingPurpose.PRINCIPAL,
                "2010",
                LocalDate.now(),
                null
        );
        glMappings.saveAndFlush(glMapping);

        em.clear();

        Product fetchedProd = products.findByProductCode("TEST_PROD").orElseThrow();
        assertThat(fetchedProd.getId()).isEqualTo(productId);
        assertThat(fetchedProd.getCreatedAt()).isNotNull();
        assertThat(fetchedProd.getUpdatedAt()).isNotNull();

        List<ProductInterestRate> fetchedRates = interestRates.findByProductId(productId);
        assertThat(fetchedRates).hasSize(1);
        assertThat(fetchedRates.get(0).getAnnualRate()).isEqualByComparingTo(new BigDecimal("0.012000"));

        List<ProductFee> fetchedFees = fees.findByProductId(productId);
        assertThat(fetchedFees).hasSize(1);
        assertThat(fetchedFees.get(0).getFeeCode()).isEqualTo("FEE_TEST");
        assertThat(fetchedFees.get(0).getAmount()).isEqualByComparingTo(new BigDecimal("5000.0000"));

        List<ProductLimit> fetchedLimits = limits.findByProductId(productId);
        assertThat(fetchedLimits).hasSize(1);
        assertThat(fetchedLimits.get(0).getLimitCode()).isEqualTo("LIM_TEST");
        assertThat(fetchedLimits.get(0).getMaxAmount()).isEqualByComparingTo(new BigDecimal("1000000000.0000"));

        List<ProductEligibilityRule> fetchedRules = rules.findByProductId(productId);
        assertThat(fetchedRules).hasSize(1);
        assertThat(fetchedRules.get(0).getRuleType()).isEqualTo(EligibilityRuleType.MIN_AGE);
        assertThat(fetchedRules.get(0).getRuleValue()).isEqualTo("18");

        List<ProductGlMapping> fetchedGlMappings = glMappings.findByProductId(productId);
        assertThat(fetchedGlMappings).hasSize(1);
        assertThat(fetchedGlMappings.get(0).getPurpose()).isEqualTo(GlMappingPurpose.PRINCIPAL);
        assertThat(fetchedGlMappings.get(0).getGlCode()).isEqualTo("2010");
    }
}
