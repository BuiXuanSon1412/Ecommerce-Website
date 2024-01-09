package com.ecomm.web.dto.product;

import com.ecomm.web.dto.store.StoreDto;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class AddProductForm {
    @NotEmpty
    private String name;
    private StoreDto store;
    @NotEmpty
    private String desc;
    @NotEmpty
    private String image;
    @NotEmpty
    private String sku;
    @NotNull
    private Integer category;
    @NotNull(message = "must not be empty")
    private Double price;
    @NotNull(message = "must not be empty")
    private Integer quantity;
}