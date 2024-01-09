package com.ecomm.web.service;

import java.util.List;

import com.ecomm.web.dto.product.AddProductForm;
import com.ecomm.web.dto.product.ProductDto;

public interface ProductService {
    void saveProduct(AddProductForm productDto);
    List<ProductDto> findAllProducts();
    ProductDto findProductById(Integer productId);
    List<ProductDto> findProductByUser(String username);
    List<ProductDto> findProductByNameAndCategory(String name, Integer categoryId);
}
