package com.ecomm.web.dto.product;

import lombok.Builder;

import java.util.List;

import com.ecomm.web.dto.store.StoreDto;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
@Builder
public class ProductDto {
    private Integer id;
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
    private CategoryDto category;
    @NotNull(message = "must not be empty")
    private Double price;
    private DiscountDto discount;
    @NotNull(message = "must not be empty")
    private Integer quantity;
}
