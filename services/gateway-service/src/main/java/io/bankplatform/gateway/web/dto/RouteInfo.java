package io.bankplatform.gateway.web.dto;

import java.util.List;

/** Một dòng trong bảng route: id, các Path pattern, và đích chuyển tiếp. */
public record RouteInfo(String id, List<String> paths, String target) {
}
