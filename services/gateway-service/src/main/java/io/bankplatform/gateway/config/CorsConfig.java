package io.bankplatform.gateway.config;

import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import org.springframework.web.filter.CorsFilter;

import java.util.List;

/**
 * CORS cho frontend dev (Vite, cổng 5173) — đặt ở gateway vì mọi request của
 * frontend đều đi qua đây: một chỗ sửa thay vì sáu. Gateway không dùng
 * javalibs nên không có javalibs.web.cors.* — filter tự khai.
 *
 * Dùng servlet Filter ở HIGHEST_PRECEDENCE — theo đúng khuôn của
 * CorsAutoConfiguration bên javalibs-web (một CorsFilter đăng ký qua
 * FilterRegistrationBean, dù bên đó dùng HIGHEST_PRECEDENCE + 10). Autoconfigure
 * đó opt-in (@ConditionalOnProperty javalibs.web.cors.enabled=true, không
 * matchIfMissing) và hiện KHÔNG service nào bật nó — ở đây chỉ mượn cách làm,
 * không phải bản sao của cái đang chạy đâu đó. Mục đích giống nhau: để header
 * CORS được gắn TRƯỚC mọi filter khác có thể tự trả response. Lưu ý cho người
 * sửa sau: addCorsMappings của WebMvcConfigurer CŨNG áp được cho route
 * RouterFunction (RouterFunctionMapping nhận chung map CORS của MVC) — chọn
 * Filter ở đây là vì nhất quán với phần còn lại của repo và thứ tự filter
 * tường minh, không phải vì RouterFunction "cần" Filter.
 */
@Configuration
public class CorsConfig {

    @Bean
    public FilterRegistrationBean<CorsFilter> corsFilter() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOrigins(List.of("http://localhost:5173"));
        config.setAllowedMethods(List.of("GET", "OPTIONS"));
        config.setAllowedHeaders(List.of("*"));

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/api/**", config);

        FilterRegistrationBean<CorsFilter> bean = new FilterRegistrationBean<>(new CorsFilter(source));
        bean.setOrder(Ordered.HIGHEST_PRECEDENCE);
        return bean;
    }
}
