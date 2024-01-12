package com.ecomm.web.service.impl;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.ecomm.web.model.product.Product;
import com.ecomm.web.dto.product.AddProductForm;
import com.ecomm.web.dto.product.ProductDto;
import com.ecomm.web.model.product.Category;
import com.ecomm.web.model.product.Inventory;
import com.ecomm.web.model.store.Store;
import com.ecomm.web.model.user.UserEntity;
import com.ecomm.web.repository.CategoryRepository;
import com.ecomm.web.repository.InventoryRepository;
import com.ecomm.web.repository.ProductRepository;
import com.ecomm.web.repository.StoreRepository;
import com.ecomm.web.repository.UserRepository;
import com.ecomm.web.security.SecurityUtil;
import com.ecomm.web.service.CategoryService;
import com.ecomm.web.service.ProductService;

import static com.ecomm.web.mapper.ProductMapper.*;

@Service
public class ProductServiceImpl implements ProductService {
    @Autowired
    private ProductRepository productRepository;
    @Autowired
    private CategoryRepository categoryRepository;
    @Autowired
    private InventoryRepository inventoryRepository;
    @Autowired
    private StoreRepository storeRepository;
    @Autowired
    private UserRepository userRepository;
    @Autowired
    private CategoryService categoryService;
    @Override
    public void saveProduct(AddProductForm productForm) {
        Category category = categoryRepository.findById(productForm.getCategory()).get();
        String username = SecurityUtil.getSessionUser();
        UserEntity user = userRepository.findByUsername(username);
        Store store = storeRepository.findByUser(user);
        
        Product product = mapFromAddProductFormToProduct(productForm);
        product.setStore(store);
        product.setCategory(category);
        product.setIsActive(true);
        productRepository.save(product);
        Inventory inventory = Inventory.builder()
                                            .product(product)
                                            .quantity(productForm.getQuantity())
                                            .status(true)
                                            .build();
        inventoryRepository.save(inventory);
    }
    @Override
    public List<ProductDto> findAllProducts() {
        List<Product> products = productRepository.findAll();
        return products.stream().map((product) -> mapToProductDto(product)).collect(Collectors.toList());
    }
    @Override
    public ProductDto findProductById(Integer productId) {
        ProductDto product = mapToProductDto(productRepository.findById(productId).get());
        product.setCategory(categoryService.findCategoryByProduct(productId));
        product.setQuantity(inventoryRepository.findQuantityByProduct(productId));
        return product;
    }
    @Override
    public List<ProductDto> findProductByUser(String username) {
        UserEntity user = userRepository.findByUsername(username);
        Store store = storeRepository.findByUser(user);
        List<Product> products = productRepository.findByStore(store);
        List<ProductDto> productDtos = new ArrayList<>();
        for(Product product : products) {
            ProductDto productDto = mapToProductDto(product);
            productDto.setCategory(categoryService.findCategoryByProduct(product.getId()));
            productDtos.add(productDto);
        }
        return productDtos;
    }
    @Override
    public List<ProductDto> findProductByNameAndCategory(String name, Integer categoryId) {
        List<Product> products = productRepository.findByNameAndCategory(name, categoryId);
        return products.stream().map((product) -> mapToProductDto(product)).collect(Collectors.toList());
    }
    
}
