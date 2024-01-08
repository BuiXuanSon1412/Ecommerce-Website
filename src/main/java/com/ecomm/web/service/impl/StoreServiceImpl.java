package com.ecomm.web.service.impl;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.ecomm.web.dto.store.StoreDto;
import com.ecomm.web.model.store.Store;
import com.ecomm.web.model.user.Role;
import com.ecomm.web.model.user.UserEntity;
import com.ecomm.web.repository.RoleRepository;
import com.ecomm.web.repository.StoreRepository;
import com.ecomm.web.repository.UserRepository;
import com.ecomm.web.security.SecurityUtil;
import com.ecomm.web.service.StoreService;

import static com.ecomm.web.mapper.StoreMapper.mapToStore;

import java.util.List;




@Service
public class StoreServiceImpl implements StoreService {
    @Autowired
    private StoreRepository storeRepository;
    @Autowired
    private UserRepository userRepository;
    @Autowired
    private RoleRepository roleRepository;
    @Override
    public void registerStore(StoreDto storeDto) {
        String username = SecurityUtil.getSessionUser();
        UserEntity user = userRepository.findByUsername(username);
        List<Role> roles = user.getRoles();
        Role role = roleRepository.findByName("SELLER");
        roles.add(role);
        user.setRoles(roles);
        userRepository.save(user);
        Store store = mapToStore(storeDto);
        store.setUser(user);
        storeRepository.save(store);
        SecurityUtil.reloadUserDetails();
    }
}
