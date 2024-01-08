package com.ecomm.web.dto.shopping;

import com.ecomm.web.dto.product.ProductDto;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class CartItemDto {
    private Integer id;
    private ProductDto product;
    private Integer quantity;
}
