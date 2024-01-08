package com.ecomm.web.dto.user;

import jakarta.validation.constraints.NotEmpty;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class Profile {
    @NotEmpty(message = "Should not be empty!")
    private String username;
    @NotEmpty(message = "Should not be empty")
    private String firstName;
    @NotEmpty(message = "Should not be empty")
    private String lastName;
    @NotEmpty(message = "Should not be empty!")
    private String telephone;
    
}
