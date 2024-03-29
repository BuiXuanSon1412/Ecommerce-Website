package com.ecomm.web.dto.product;

import java.time.LocalDate;

import com.ecomm.web.dto.store.StoreDto;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class DiscountDto {
    private Integer id;
    private String name;
    private String desc;
    private Double disc;
    private LocalDate startDate;
    private LocalDate endDate;
    private Boolean isActive;
    private StoreDto store;
}
