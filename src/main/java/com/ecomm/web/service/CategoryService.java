package com.ecomm.web.service;

import java.util.List;

import com.ecomm.web.dto.product.CategoriesDto;
import com.ecomm.web.dto.product.CategoryDto;

public interface CategoryService {
    List<CategoryDto> findAllBaseCategories(); 
    //List<CategoryDto> findCategoriesByProduct(Integer productId);
    public List<CategoriesDto> findAllLevelCategories();
}
