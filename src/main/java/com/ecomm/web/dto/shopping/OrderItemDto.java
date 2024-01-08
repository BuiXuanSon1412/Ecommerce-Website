package com.ecomm.web.dto.shopping;

import com.ecomm.web.dto.product.ProductDto;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class OrderItemDto {
    private ProductDto product;
    private Integer quantity;
    private String condition;
    private String paymentType;
}
