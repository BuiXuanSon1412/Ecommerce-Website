package com.ecomm.web.mapper;

import com.ecomm.web.dto.product.CategoryDto;
import com.ecomm.web.model.product.Category;

public class CategoryMapper {
    public static CategoryDto mapToCategoryDto(Category category) {
        return CategoryDto.builder()
                            .id(category.getId())
                            .name(category.getName())
                            .desc(category.getDesc())
                            .build();
    }
}
