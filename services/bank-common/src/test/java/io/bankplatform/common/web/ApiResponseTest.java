package io.bankplatform.common.web;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Ghim HÌNH DẠNG envelope. Năm ServiceInfoApiTest đọc thẳng JSON
 * (body.path("success"), body.path("data")), nên đổi tên hay thứ tự trường ở
 * đây là làm đỏ test của cả năm service — và làm hỏng frontend đang chạy.
 */
class ApiResponseTest {

    @Test
    void okDatSuccessTrueVaGiuNguyenPayload() {
        ApiResponse<String> res = ApiResponse.ok("xin chào");

        assertThat(res.success()).isTrue();
        assertThat(res.data()).isEqualTo("xin chào");
        assertThat(res.message()).isNull();
        assertThat(res.timestamp()).isNotNull();
        assertThat(res.traceId()).isNull();
    }

    @Test
    void okCoMessage() {
        ApiResponse<String> res = ApiResponse.ok("dữ liệu", "đã tạo");

        assertThat(res.success()).isTrue();
        assertThat(res.message()).isEqualTo("đã tạo");
    }

    @Test
    void errorDatSuccessFalseVaDataNull() {
        ApiResponse<String> res = ApiResponse.error("hỏng rồi");

        assertThat(res.success()).isFalse();
        assertThat(res.data()).isNull();
        assertThat(res.message()).isEqualTo("hỏng rồi");
    }

    @Test
    void errorCoTraceId() {
        ApiResponse<String> res = ApiResponse.error("hỏng rồi", "abc-123");

        assertThat(res.traceId()).isEqualTo("abc-123");
    }

    @Test
    void thuTuTruongCuaRecordDungNhuHopDong() {
        // RecordComponents theo đúng thứ tự khai báo. Jackson serialize theo
        // thứ tự này, và đây là thứ frontend/test nhìn thấy.
        assertThat(ApiResponse.class.getRecordComponents())
                .extracting(java.lang.reflect.RecordComponent::getName)
                .containsExactly("success", "data", "message", "timestamp", "traceId");
    }
}
