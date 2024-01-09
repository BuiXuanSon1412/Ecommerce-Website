package com.ecomm.web.service;

import java.util.List;

import com.ecomm.web.dto.product.CategoriesDto;
import com.ecomm.web.dto.product.CategoryDto;

public interface CategoryService {
    List<CategoryDto> findAllBaseCategories(); 
    public List<CategoriesDto> findAllLevelCategories();
}
