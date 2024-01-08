package com.ecomm.web.dto.user;

import java.time.LocalDate;

import org.springframework.format.annotation.DateTimeFormat;

import lombok.Builder;
import jakarta.validation.constraints.NotEmpty;
import lombok.Data;

@Data
@Builder
public class PaymentDto {
    private Integer id;
    @NotEmpty
    private String paymentType;
    @NotEmpty
    private String provider;
    @NotEmpty
    private String accountNo;
    @DateTimeFormat(pattern = "yyyy/DD/mm")
    private LocalDate expiry;
}
