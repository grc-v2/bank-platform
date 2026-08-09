package io.javalibs.openapi.autoconfigure;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.SpringBootConfiguration;
import org.springframework.boot.autoconfigure.EnableAutoConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Exercises the <b>real</b> springdoc-openapi auto-configuration on top of
 * {@link JavalibsOpenApiAutoConfiguration}, not a hand-built {@link
 * io.swagger.v3.oas.models.OpenAPI} POJO.
 *
 * <p>{@link JavalibsOpenApiAutoConfigurationTest} only ever registers {@code
 * JavalibsOpenApiAutoConfiguration} in isolation: it never loads springdoc's
 * own configuration classes ({@code SpringDocConfiguration}, {@code
 * SpringDocWebMvcConfiguration}, ...), never starts a {@code
 * DispatcherServlet}, and never calls {@code GET /v3/api-docs}. springdoc
 * builds that document by reflecting over {@code RequestMappingHandlerMapping}
 * / {@code HandlerMethod} / {@code RequestMappingInfo} — exactly the internal
 * Spring MVC surface that changed between Spring Framework 6 and 7. A
 * reflection break there would leave the POJO-only tests green while {@code
 * GET /v3/api-docs} fails (or the context fails to start) on a real service.
 *
 * <p>This test wires a genuine {@code @RestController} into a full {@code
 * @EnableAutoConfiguration} context (which pulls in every {@code
 * AutoConfiguration.imports} entry on the test classpath — springdoc's
 * three files plus {@code JavalibsOpenApiAutoConfiguration}'s own) and hits
 * {@code GET /v3/api-docs} through {@link MockMvc}. If springdoc cannot
 * generate the document on Spring Framework 7, this test fails: either the
 * context refresh throws (reflection error surfaces at startup) or the
 * endpoint returns something other than a 200 with a well-formed OpenAPI
 * document.
 */
@SpringBootTest(
        classes = JavalibsOpenApiSpringdocIntegrationTest.TestApp.class,
        webEnvironment = SpringBootTest.WebEnvironment.MOCK,
        properties = "spring.application.name=orders-service")
@AutoConfigureMockMvc
class JavalibsOpenApiSpringdocIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void springdocGeneratesRealOpenApiDocumentFromARestController() throws Exception {
        mockMvc.perform(get("/v3/api-docs"))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                // Springdoc actually discovered the controller below via
                // RequestMappingHandlerMapping reflection.
                .andExpect(jsonPath("$.paths./sample.get").exists())
                // javalibs customization: bearer-JWT security scheme from
                // JavalibsOpenApiAutoConfiguration made it into the real document.
                .andExpect(jsonPath("$.components.securitySchemes.bearerAuth.scheme")
                        .value("bearer"))
                // javalibs customization: GlobalErrorResponsesCustomizer ran as an
                // actual springdoc GlobalOpenApiCustomizer, not a hand-called method.
                .andExpect(jsonPath("$.paths./sample.get.responses.404.description")
                        .value("Not found — resource does not exist"))
                .andExpect(jsonPath("$.paths./sample.get.responses.404.content"
                        + ".['application/json'].schema.$ref")
                        .value("#/components/schemas/ErrorResponse"));
    }

    @SpringBootConfiguration
    @EnableAutoConfiguration
    @Import(SampleController.class)
    static class TestApp {
    }

    @RestController
    static class SampleController {

        @GetMapping("/sample")
        String sample() {
            return "ok";
        }
    }
}
