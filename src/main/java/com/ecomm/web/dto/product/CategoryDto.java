package com.ecomm.web.dto.product;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class CategoryDto {
    private Integer id;
    private String name;
    private String desc;
}
