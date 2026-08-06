package io.javalibs.cache.spring;

import com.fasterxml.jackson.annotation.JsonTypeInfo;
import io.javalibs.cache.CacheKeys;
import org.springframework.data.redis.cache.RedisCacheConfiguration;
import org.springframework.data.redis.serializer.GenericJacksonJsonRedisSerializer;
import org.springframework.data.redis.serializer.RedisSerializationContext;
import org.springframework.data.redis.serializer.StringRedisSerializer;
import tools.jackson.databind.DatabindContext;
import tools.jackson.databind.DefaultTyping;
import tools.jackson.databind.JavaType;
import tools.jackson.databind.cfg.DateTimeFeature;
import tools.jackson.databind.jsontype.PolymorphicTypeValidator;
import tools.jackson.databind.jsontype.impl.DefaultTypeResolverBuilder;

import java.time.Duration;

/**
 * Factory for the standard javalibs {@link RedisCacheConfiguration}: String keys
 * with the {@code <prefix>::<cacheName>::} convention and JSON values.
 *
 * <p><strong>Serialization trade-off:</strong> values are serialized with
 * {@link GenericJacksonJsonRedisSerializer}, which embeds the Java class name
 * ({@code @class}) in the JSON so entries deserialize without per-cache type
 * configuration. Consequences: (1) renaming/moving a cached DTO class breaks
 * existing entries — flush the affected caches when refactoring cached types;
 * (2) caches must not be shared between services that do not share the DTO
 * classes. Keep cached values as small, dedicated DTOs.
 */
public final class RedisCacheConfigurations {

    private RedisCacheConfigurations() {
    }

    /**
     * Builds the standard cache configuration.
     *
     * @param keyPrefix       application-level prefix (usually the service name);
     *                        full keys become {@code <keyPrefix>::<cacheName>::<key>}
     * @param ttl             entry time-to-live
     * @param cacheNullValues whether {@code null} values are cached
     * @return the configuration to use as default or per-cache override
     */
    public static RedisCacheConfiguration standard(String keyPrefix, Duration ttl, boolean cacheNullValues) {
        RedisCacheConfiguration config = RedisCacheConfiguration.defaultCacheConfig()
                .entryTtl(ttl)
                .prefixCacheNameWith(keyPrefix + CacheKeys.SECTION_SEPARATOR)
                .serializeKeysWith(RedisSerializationContext.SerializationPair
                        .fromSerializer(new StringRedisSerializer()))
                .serializeValuesWith(RedisSerializationContext.SerializationPair
                        .fromSerializer(jsonSerializer()));
        return cacheNullValues ? config : config.disableCachingNullValues();
    }

    /**
     * JSON value serializer with {@code java.time} support and default typing so
     * records and final classes round-trip (see class Javadoc for the trade-offs).
     *
     * <p>{@code java.time} support is native to jackson-databind on Jackson 3 (the
     * former {@code jackson-datatype-jsr310} module was folded into jackson-databind
     * itself), so no module registration is needed here anymore.
     */
    public static GenericJacksonJsonRedisSerializer jsonSerializer() {
        return GenericJacksonJsonRedisSerializer.builder()
                .enableSpringCacheNullValueSupport()
                .customize(builder -> builder
                        .disable(DateTimeFeature.WRITE_DATES_AS_TIMESTAMPS)
                        .setDefaultTyping(new EverythingTypeResolverBuilder(UnsafeAnySubTypeValidator.INSTANCE)))
                .build();
    }

    /**
     * Types every non-primitive value, matching Jackson 2's {@code DefaultTyping.EVERYTHING}
     * (deprecated since 2.17, removed in Jackson 3.0 — see its javadoc: "only known use case
     * ... is for serialization when passing instances of final class").
     *
     * <p>None of the {@link DefaultTyping} values Jackson 3 kept cover this: the strongest,
     * {@code NON_FINAL_AND_RECORDS}, still skips ordinary final classes such as
     * {@link java.time.LocalDate} — exactly the case the frozen milestone in
     * {@code CHANGELOG-2.0.md} depends on ({@code day} is wrapped as
     * {@code ["java.time.LocalDate","2026-08-02"]}). This replicates
     * {@code DefaultTyping.EVERYTHING}'s exact behavior, taken from the Jackson 2 source
     * ({@code case EVERYTHING: return true;}, reached only after primitives are excluded):
     * type everything that is not a primitive. "Natural" types (String, Boolean, Integer,
     * Double) are still skipped, but by Jackson's own serializer/deserializer plumbing, not by
     * this method.
     */
    private static final class EverythingTypeResolverBuilder extends DefaultTypeResolverBuilder {

        EverythingTypeResolverBuilder(PolymorphicTypeValidator validator) {
            // The DefaultTyping value passed here is irrelevant: useForType() below is
            // fully overridden and never consults it.
            super(validator, DefaultTyping.NON_FINAL_AND_RECORDS, JsonTypeInfo.As.PROPERTY);
        }

        @Override
        public boolean useForType(JavaType t) {
            return !t.isPrimitive();
        }
    }

    /**
     * Allows every subtype during polymorphic deserialization — the same
     * "laissez-faire" trade-off the class Javadoc documents.
     *
     * <p>Jackson 2's {@code LaissezFaireSubTypeValidator} did this and was public API.
     * Jackson 3 ships the identical class
     * ({@code tools.jackson.databind.jsontype.impl.LaissezFaireSubTypeValidator}) but as
     * package-private internal API with no compatibility guarantee, so it cannot be
     * referenced from here. This replicates its exact validation logic (verified by
     * disassembling the Jackson 3 class: {@code validateBaseType} returns
     * {@code INDETERMINATE}, {@code validateSubClassName}/{@code validateSubType} return
     * {@code ALLOWED}) to keep the cached JSON shape byte-for-byte identical.
     */
    private static final class UnsafeAnySubTypeValidator extends PolymorphicTypeValidator {

        private static final UnsafeAnySubTypeValidator INSTANCE = new UnsafeAnySubTypeValidator();

        @Override
        public Validity validateBaseType(DatabindContext ctxt, JavaType baseType) {
            return Validity.INDETERMINATE;
        }

        @Override
        public Validity validateSubClassName(DatabindContext ctxt, JavaType baseType, String subClassName) {
            return Validity.ALLOWED;
        }

        @Override
        public Validity validateSubType(DatabindContext ctxt, JavaType baseType, JavaType subType) {
            return Validity.ALLOWED;
        }
    }
}
