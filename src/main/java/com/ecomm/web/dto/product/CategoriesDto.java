package com.ecomm.web.dto.product;

import java.util.List;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class CategoriesDto {
    private CategoryDto baseCategory;
    private List<CategoryDto> subCategories;
}
