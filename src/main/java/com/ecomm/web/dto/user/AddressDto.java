package com.ecomm.web.dto.user;

import jakarta.validation.constraints.NotEmpty;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class AddressDto {
    private Integer id;
    @NotEmpty
    private String address;
    @NotEmpty
    private String city;
    @NotEmpty
    private String postalCode;
    @NotEmpty
    private String country;
    
}
