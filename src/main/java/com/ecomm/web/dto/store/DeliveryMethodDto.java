package com.ecomm.web.dto.store;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class DeliveryMethodDto {
    private Integer id;
    private StoreDto store;
    private String methodName;
    private Double price;
    private Boolean isActive;
}
