package com.ecomm.web.dto.store;


import jakarta.validation.constraints.NotEmpty;
import lombok.Builder;
import lombok.Data;

@Data
@Builder

public class StoreDto {
    private Integer id;
    @NotEmpty
    private String name;
    @NotEmpty
    private String description;
}
