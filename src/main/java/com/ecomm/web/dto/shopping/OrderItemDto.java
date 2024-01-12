package com.ecomm.web.dto.shopping;

import java.time.LocalDateTime;

import com.ecomm.web.dto.product.ProductDto;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class OrderItemDto {
    private ProductDto product;
    private Integer quantity;
    private String condition;
    private String deliveryMethod;
    private LocalDateTime modifiedAt;
}
