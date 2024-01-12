package com.ecomm.web.service.impl;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.util.Pair;
import org.springframework.stereotype.Service;

import com.ecomm.web.dto.product.CategoriesDto;
import com.ecomm.web.dto.product.CategoryDto;
import com.ecomm.web.model.product.Category;
import com.ecomm.web.model.product.Product;
import com.ecomm.web.repository.CategoryRepository;
import com.ecomm.web.service.CategoryService;

import static com.ecomm.web.mapper.CategoryMapper.mapToCategoryDto;

@Service
public class CategoryServiceImpl implements CategoryService {
    @Autowired
    private CategoryRepository categoryRepository;
    @Override
    public List<CategoryDto> findAllBaseCategories(){
        List<Category> productCategories = categoryRepository.findAllBaseCategories();
        return productCategories.stream().map((productCategory) -> mapToCategoryDto(productCategory)).collect(Collectors.toList());
    }
    @Override
    public List<CategoriesDto> findAllLevelCategories() {
        List<CategoriesDto> categoriesByBase = new ArrayList<>();;
        List<Category> baseCategories = categoryRepository.findAllBaseCategories();
        for(Category c : baseCategories) {
            List<Category> categories = categoryRepository.findSubCategoriesByBaseCategories(c.getId());
            List<CategoryDto> categoryDtoes = categories.stream().map((category) -> mapToCategoryDto(category)).collect(Collectors.toList());
            CategoriesDto categoriesDto = CategoriesDto.builder()
                                                        .baseCategory(mapToCategoryDto(c))
                                                        .subCategories(categoryDtoes)
                                                        .build();
            categoriesByBase.add(categoriesDto);
        }
        return categoriesByBase;
    }
    @Override
    public Pair<CategoryDto, CategoryDto> findCategoryByProduct(Integer productId) {
        List<Object[]> resultSet = categoryRepository.findCategoryByProduct(productId);
        CategoryDto sub = CategoryDto.builder().build();
        CategoryDto base = CategoryDto.builder().build();
        for(Object[] result : resultSet) {
            sub = CategoryDto.builder()
                                            .id((Integer)result[0])
                                            .name((String)result[1])
                                            .desc((String)result[2])
                                            .build();
            base = CategoryDto.builder()
                                            .id((Integer)result[3])
                                            .name((String)result[4])
                                            .desc((String)result[5])
                                            .build();
        }
        Pair<CategoryDto, CategoryDto> category = Pair.of(base, sub);
        return category;
                                                      
    }
}
