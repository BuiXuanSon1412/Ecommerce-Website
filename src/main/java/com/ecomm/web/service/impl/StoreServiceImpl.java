package com.ecomm.web.service.impl;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.util.Pair;
import org.springframework.stereotype.Service;

import com.ecomm.web.dto.delivery.DeliveryProviderDto;
import com.ecomm.web.dto.store.DeliveryMethodDto;
import com.ecomm.web.dto.store.StoreDto;
import com.ecomm.web.model.delivery.DeliveryProvider;
import com.ecomm.web.model.store.DeliveryMethod;
import com.ecomm.web.model.store.Store;
import com.ecomm.web.model.user.Role;
import com.ecomm.web.model.user.UserEntity;
import com.ecomm.web.repository.DeliveryMethodRepository;
import com.ecomm.web.repository.DeliveryProviderRepository;
import com.ecomm.web.repository.RoleRepository;
import com.ecomm.web.repository.StoreRepository;
import com.ecomm.web.repository.UserRepository;
import com.ecomm.web.security.SecurityUtil;
import com.ecomm.web.service.StoreService;

import jakarta.validation.OverridesAttribute;

import static com.ecomm.web.mapper.StoreMapper.mapToStore;
import static com.ecomm.web.mapper.StoreMapper.mapToStoreDto;
import static com.ecomm.web.mapper.DeliveryMethodMapper.mapToDeliveryMethodDto;
import static com.ecomm.web.mapper.DeliveryProviderMapper.mapToDeliveryProviderDto;
import java.util.List;
import java.util.stream.Collectors;




@Service
public class StoreServiceImpl implements StoreService {
    @Autowired
    private StoreRepository storeRepository;
    @Autowired
    private UserRepository userRepository;
    @Autowired
    private RoleRepository roleRepository;
    @Autowired
    private DeliveryProviderRepository deliveryProviderRepository;
    @Autowired
    private DeliveryMethodRepository deliveryMethodRepository;
    @Override
    public void registerStore(StoreDto storeDto) {
        String username = SecurityUtil.getSessionUser();
        UserEntity user = userRepository.findByUsername(username);
        List<Role> roles = user.getRoles();
        Role role = roleRepository.findByName("SELLER");
        roles.add(role);
        user.setRoles(roles);
        userRepository.save(user);
        Store s = mapToStore(storeDto);
        s.setUser(user);
        storeRepository.save(s);
        SecurityUtil.reloadUserDetails();
    }
    @Override
    public List<DeliveryProviderDto> findAll() {
        return deliveryProviderRepository.findAll().stream().map((deliveryProvider) -> mapToDeliveryProviderDto(deliveryProvider)).collect(Collectors.toList());
    }

    @Override
    public List<DeliveryMethodDto> findDeliveryMethodByUsername(String username) {
        UserEntity user = userRepository.findByUsername(username);
        Store store = storeRepository.findByUser(user);
        List<DeliveryMethod> deliveryMethods = deliveryMethodRepository.findByStore(store);
        return deliveryMethods.stream().map((deliveryMethod) -> mapToDeliveryMethodDto(deliveryMethod)).collect(Collectors.toList());
    }
    @Override
    public boolean updateMethod(String methodName, String username) {
        UserEntity user = userRepository.findByUsername(username);
        Store store = storeRepository.findByUser(user);
        DeliveryMethod deliveryMethod = deliveryMethodRepository.findByMethodNameAndStore(methodName, store.getId());
        if(deliveryMethod != null) {
            deliveryMethod.setIsActive(!deliveryMethod.getIsActive());
            deliveryMethodRepository.save(deliveryMethod);
            return true;
        }
        return false;
    }
    @Override
    public StoreDto findStoreByUsername(String username) {
        UserEntity user = userRepository.findByUsername(username);
        Store store = storeRepository.findByUser(user);
        return mapToStoreDto(store);
    }
    @Override
    public void saveStore(StoreDto storeDto) {
        Store store = storeRepository.findById(storeDto.getId()).get();
        store.setName(storeDto.getName());
        store.setDescription(store.getDescription());
        storeRepository.save(store);
    }
}
