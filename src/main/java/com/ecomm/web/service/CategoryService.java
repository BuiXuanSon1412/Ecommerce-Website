package com.ecomm.web.service;

import java.util.List;

import org.springframework.data.util.Pair;

import com.ecomm.web.dto.product.CategoriesDto;
import com.ecomm.web.dto.product.CategoryDto;

public interface CategoryService {
    List<CategoryDto> findAllBaseCategories(); 
    public List<CategoriesDto> findAllLevelCategories();
    public Pair<CategoryDto, CategoryDto> findCategoryByProduct(Integer productId);
}
