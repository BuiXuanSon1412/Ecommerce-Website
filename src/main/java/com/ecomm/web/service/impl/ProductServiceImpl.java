package com.ecomm.web.service.impl;

import java.util.List;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.ecomm.web.model.product.Product;
import com.ecomm.web.dto.product.ProductDto;
import com.ecomm.web.model.product.Category;
import com.ecomm.web.model.product.Inventory;
import com.ecomm.web.model.store.Store;
import com.ecomm.web.model.user.UserEntity;
import com.ecomm.web.repository.CategoryRepository;
import com.ecomm.web.repository.ProductInventoryRepository;
import com.ecomm.web.repository.ProductRepository;
import com.ecomm.web.repository.StoreRepository;
import com.ecomm.web.repository.UserRepository;
import com.ecomm.web.security.SecurityUtil;
import com.ecomm.web.service.ProductService;

import static com.ecomm.web.mapper.ProductMapper.mapToProductDto;
import static com.ecomm.web.mapper.ProductMapper.mapToProduct;

@Service
public class ProductServiceImpl implements ProductService {
    @Autowired
    private ProductRepository productRepository;
    @Autowired
    private CategoryRepository categoryRepository;
    @Autowired
    private ProductInventoryRepository productInventoryRepository;
    @Autowired
    private StoreRepository storeRepository;
    @Autowired
    private UserRepository userRepository;
    @Override
    public void saveProduct(ProductDto productDto) {
        Category category = categoryRepository.findById(productDto.getCategory().getId()).get();
        String username = SecurityUtil.getSessionUser();
        UserEntity user = userRepository.findByUsername(username);
        Store store = storeRepository.findByUser(user);
        
        Product product = mapToProduct(productDto);
        product.setStore(store);
        product.setCategory(category);
        productRepository.save(product);
        Inventory productInventory = Inventory.builder()
                                            .product(product)
                                            .quantity(productDto.getQuantity())
                                            .build();
        productInventoryRepository.save(productInventory);
    }
    @Override
    public List<ProductDto> findAllProducts() {
        List<Product> products = productRepository.findAll();
        return products.stream().map((product) -> mapToProductDto(product)).collect(Collectors.toList());
    }
    @Override
    public ProductDto findProductById(Integer productId) {
        return mapToProductDto(productRepository.findById(productId).get());
    }
    @Override
    public List<ProductDto> findProductByUser(String username) {
        UserEntity user = userRepository.findByUsername(username);
        Store store = storeRepository.findByUser(user);
        List<Product> products = productRepository.findByStore(store);
        return products.stream().map((product) -> mapToProductDto(product)).collect(Collectors.toList());
    }
    @Override
    public List<ProductDto> findProductByNameAndCategory(String name, Integer categoryId) {
        List<Product> products = productRepository.findByNameAndCategory(name, categoryId);
        return products.stream().map((product) -> mapToProductDto(product)).collect(Collectors.toList());
    }
}
