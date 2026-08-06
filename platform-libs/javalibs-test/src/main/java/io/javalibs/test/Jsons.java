package io.javalibs.test;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.cfg.DateTimeFeature;
import tools.jackson.databind.json.JsonMapper;

/**
 * JSON helpers for tests: serialization round-trips and structural equality
 * assertions independent of key order and formatting.
 *
 * <p>{@code java.time} support is native to jackson-databind on Jackson 3 (the former
 * {@code jackson-datatype-jsr310} module was folded into jackson-databind itself), so no
 * module registration is needed here anymore.
 */
public final class Jsons {

    private static final ObjectMapper MAPPER = JsonMapper.builder()
            .disable(DateTimeFeature.WRITE_DATES_AS_TIMESTAMPS)
            .build();

    private Jsons() {
    }

    /** Shared, pre-configured mapper (Java time as ISO-8601 strings). */
    public static ObjectMapper mapper() {
        return MAPPER;
    }

    public static String toJson(Object value) {
        try {
            return MAPPER.writeValueAsString(value);
        } catch (Exception e) {
            throw new AssertionError("Failed to serialize " + value.getClass() + " to JSON", e);
        }
    }

    public static <T> T fromJson(String json, Class<T> type) {
        try {
            return MAPPER.readValue(json, type);
        } catch (Exception e) {
            throw new AssertionError("Failed to deserialize JSON to " + type, e);
        }
    }

    /**
     * Asserts that two JSON documents are structurally equal (ignoring key order
     * and whitespace). Throws {@link AssertionError} with both documents in the
     * message when they differ.
     */
    public static void assertEquivalent(String expectedJson, String actualJson) {
        JsonNode expected = readTree(expectedJson, "expected");
        JsonNode actual = readTree(actualJson, "actual");
        if (!expected.equals(actual)) {
            throw new AssertionError(
                    "JSON documents differ.%nExpected: %s%nActual:   %s".formatted(expected, actual));
        }
    }

    private static JsonNode readTree(String json, String label) {
        try {
            return MAPPER.readTree(json);
        } catch (Exception e) {
            throw new AssertionError("Invalid " + label + " JSON: " + json, e);
        }
    }
}
